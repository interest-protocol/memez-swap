module amm::interest_protocol_amm {
  // === Imports ===
  use std::ascii;
  use std::string;
  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};

  use suitears::math64::{min, mul_div_down}; 
  use suitears::math256::{sqrt_down, mul_div_up};

  use amm::utils;
  use amm::errors;
  use amm::stable;
  use amm::events;
  use amm::volatile; 
  use amm::admin::Admin;
  use amm::fees::{Self, Fees};
  use amm::curves::{Self, Volatile, Stable};
  use amm::auction::{Self, Auction, Account};

  // === Constants ===

  const PRECISION: u256 = 1_000_000_000_000_000_000;
  const MINIMUM_LIQUIDITY: u64 = 100;
  const INITIAL_STABLE_FEE_PERCENT: u256 = 250_000_000_000_000; // 0.025%
  const INITIAL_VOLATILE_FEE_PERCENT: u256 = 3_000_000_000_000_000; // 0.3%
  const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%
  const FLASH_LOAN_FEE_PERCENT: u256 = 5_000_000_000_000_000; //0.5% 

  // === Structs ===

  struct Registry has key {
    id: UID,
    pools: Table<TypeName, address>
  }
  
  struct InterestPool has key {
    id: UID 
  }

  struct RegistryKey<phantom Curve, phantom CoinX, phantom CoinY> has drop {}

  struct PoolStateKey has drop, copy, store {}

  struct PoolState<phantom CoinX, phantom CoinY, phantom LpCoin> has store {
    lp_coin_cap: TreasuryCap<LpCoin>,
    balance_x: Balance<CoinX>,
    balance_y: Balance<CoinY>,
    decimals_x: u64,
    decimals_y: u64,
    admin_balance_x: Balance<CoinX>,
    admin_balance_y: Balance<CoinY>,
    seed_liquidity: Balance<LpCoin>,
    admin_lp_coin_balance: Balance<LpCoin>,
    fees: Fees,
    volatile: bool,
    manager: Manager,
    manager_balances: Table<address, ManagerBalances<CoinX, CoinY>>,
    locked: bool     
  } 

  struct Manager has store {
    address: address,
    start: u64,
    end: u64,
    fees: Fees,
  }

  struct ManagerBalances<phantom CoinX, phantom CoinY> has store {
    balance_x: Balance<CoinX>,
    balance_y: Balance<CoinY>
  }

  struct SwapAmount has store, drop, copy {
    amount_out: u64,
    admin_fee_in: u64,
    admin_fee_out: u64,
    manager_fee_in: u64,
    manager_fee_out: u64,
    standard_fee_in: u64,
    standard_fee_out: u64,
  }

  struct Invoice {
    pool_address: address,
    repay_amount_x: u64,
    repay_amount_y: u64,
    prev_k: u256
  }

  // === Public-Mutative Functions ===

  #[allow(unused_function)]
  fun init(ctx: &mut TxContext) {
    share_object(
      Registry {
        id: object::new(ctx),
        pools: table::new(ctx)
      }
    );
  }  

  // === DEX ===

  #[lint_allow(share_owned)]
  public fun new<CoinX, CoinY, LpCoin>(
    registry: &mut Registry,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>,
    lp_coin_cap: TreasuryCap<LpCoin>,
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,  
    lp_coin_metadata: &mut CoinMetadata<LpCoin>,
    volatile: bool,
    ctx: &mut TxContext    
  ): Coin<LpCoin> {
    utils::assert_lp_coin_integrity<CoinX, CoinY, LpCoin>(lp_coin_metadata, volatile);
    
    coin::update_name(&lp_coin_cap, lp_coin_metadata, utils::get_lp_coin_name(coin_x_metadata, coin_y_metadata, volatile));
    coin::update_symbol(&lp_coin_cap, lp_coin_metadata, utils::get_lp_coin_symbol(coin_x_metadata, coin_y_metadata, volatile));

    let decimals_x = pow(10, coin::get_decimals(coin_x_metadata));
    let decimals_y = pow(10, coin::get_decimals(coin_y_metadata));

    if (volatile)
      new_pool_internal<Volatile, CoinX, CoinY, LpCoin>(registry, coin_x, coin_y, lp_coin_cap, decimals_x, decimals_y, true, ctx)
    else 
      new_pool_internal<Stable, CoinX, CoinY, LpCoin>(registry, coin_x, coin_y, lp_coin_cap, decimals_x, decimals_y, false, ctx)
  }

  public fun swap<CoinIn, CoinOut, LpCoin>(
    pool: &mut InterestPool, 
    clock: &Clock,
    coin_in: Coin<CoinIn>,
    coin_min_value: u64,
    ctx: &mut TxContext    
  ): Coin<CoinOut> {
    assert!(coin::value(&coin_in) != 0, errors::no_zero_coin());

    if (utils::is_coin_x<CoinIn, CoinOut>()) 
      swap_coin_x<CoinIn, CoinOut, LpCoin>(pool, clock, coin_in, coin_min_value, ctx)
    else 
      swap_coin_y<CoinOut, CoinIn, LpCoin>(pool, clock,  coin_in, coin_min_value, ctx)
  }

  public fun add_liquidity<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>,
    lp_coin_min_amount: u64,
    ctx: &mut TxContext 
  ): (Coin<LpCoin>, Coin<CoinX>, Coin<CoinY>) {
    let coin_x_value = coin::value(&coin_x);
    let coin_y_value = coin::value(&coin_y);       

    assert!(coin_x_value != 0 && coin_y_value != 0, errors::provide_both_coins());

    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let (balance_x, balance_y, lp_coin_supply) = amounts(pool_state);

    let (optimal_x_amount, optimal_y_amount) = utils::get_optimal_add_liquidity(
      coin_x_value,
      coin_y_value,
      balance_x,
      balance_y
    );   

    let extra_x = if (coin_x_value > optimal_x_amount) coin::split(&mut coin_x, coin_x_value - optimal_x_amount, ctx) else coin::zero<CoinX>(ctx); 
    let extra_y = if (coin_y_value > optimal_y_amount) coin::split(&mut coin_y, coin_y_value - optimal_y_amount, ctx) else coin::zero<CoinY>(ctx); 

    // round down to give the protocol an edge
    let shares_to_mint = min(
      mul_div_down(coin::value(&coin_x), lp_coin_supply, balance_x),
      mul_div_down(coin::value(&coin_y), lp_coin_supply, balance_y)
    );

    assert!(shares_to_mint >= lp_coin_min_amount, errors::slippage());

    balance::join(&mut pool_state.balance_x, coin::into_balance(coin_x));
    balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));

    events::add_liquidity<CoinX, CoinY>(pool_address, optimal_x_amount, optimal_y_amount, shares_to_mint);

    (coin::from_balance(balance::increase_supply(coin::supply_mut(&mut pool_state.lp_coin_cap), shares_to_mint), ctx), extra_x, extra_y)
  }

  public fun remove_liquidity<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    clock: &Clock,
    lp_coin: Coin<LpCoin>,
    coin_x_min_amount: u64,
    coin_y_min_amount: u64,
    ctx: &mut TxContext
  ): (Coin<CoinX>, Coin<CoinY>) {
    let lp_coin_value = coin::value(&lp_coin);

    assert!(lp_coin_value != 0, errors::no_zero_coin());
    
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let (balance_x, balance_y, lp_coin_supply) = amounts(pool_state);

    let coin_x_removed = mul_div_down(lp_coin_value, balance_x, lp_coin_supply);
    let coin_y_removed = mul_div_down(lp_coin_value, balance_y, lp_coin_supply);

    balance::decrease_supply(coin::supply_mut(&mut pool_state.lp_coin_cap), coin::into_balance(lp_coin));

    let coin_x = coin::take(&mut pool_state.balance_x, coin_x_removed, ctx);
    let coin_y = coin::take(&mut pool_state.balance_y, coin_y_removed, ctx);

    let manager_coin_x_value = fees::get_remove_liquidity_amount(&pool_state.manager.fees, coin_x_removed);
    let manager_coin_y_value = fees::get_remove_liquidity_amount(&pool_state.manager.fees, coin_y_removed);

    if (are_manager_fees_active_impl(pool_state, clock) && fees::remove_liquidity_fee_percent(&pool_state.manager.fees) != 0) {
      add_manager_fee_x(pool_state, coin::split(&mut coin_x, manager_coin_x_value, ctx));
      add_manager_fee_y(pool_state, coin::split(&mut coin_y, manager_coin_y_value, ctx));
    };    

    assert!(coin::value(&coin_x) >= coin_x_min_amount, errors::slippage());
    assert!(coin::value(&coin_y) >= coin_y_min_amount, errors::slippage());

    events::remove_liquidity<CoinX, CoinY>(
      pool_address, 
      coin::value(&coin_x), 
      coin::value(&coin_y), 
      lp_coin_value,
      manager_coin_x_value,
      manager_coin_y_value
    );

    (coin_x, coin_y)
  }  

  // === Auction ===

  public fun burn_manager_deposits<CoinX, CoinY, LpCoin>(pool: &mut InterestPool, auction: &mut Auction<LpCoin>, ctx: &mut TxContext): u64 {
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    let burn_balance = auction::burn_wallet_mut(auction);

    let admin_amount = fees::get_admin_amount(&pool_state.fees, balance::value(burn_balance));

    balance::join(&mut pool_state.admin_lp_coin_balance, balance::split(burn_balance, admin_amount));

    events::manager_burn<LpCoin>(pool_address, balance::value(burn_balance), admin_amount);

    coin::burn(&mut pool_state.lp_coin_cap, coin::from_balance(balance::withdraw_all(burn_balance), ctx))
  }

  public fun set_manager_fees<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    auction: &Auction<LpCoin>, 
    clock: &Clock,
    account: &Account,
    fee_in_percent: Option<u256>,
    fee_out_percent: Option<u256>, 
    remove_liquidity_fee_percent: Option<u256>,   
  ) {
    auction::assert_is_manager_active<LpCoin>(auction, clock, account);
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    pool_state.manager.address = auction::account_address(account);
    pool_state.manager.start = auction::active_manager_start(auction);
    pool_state.manager.end = auction::active_manager_end(auction);

    fees::update_fee_in_percent(&mut pool_state.fees, fee_in_percent);
    fees::update_fee_out_percent(&mut pool_state.fees, fee_out_percent);  
    fees::update_remove_liquidity_fee_percent(&mut pool_state.fees, remove_liquidity_fee_percent);

    events::manager_fees(
      pool_address, 
      pool_state.manager.address, 
      pool_state.manager.start, 
      pool_state.manager.end, 
      pool_state.manager.fees
    );      
  }

  public fun take_manager_fees<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    account: &Account,
    ctx: &mut TxContext
  ): (Coin<CoinX>, Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    let manager_balance = table::borrow_mut(
      &mut pool_state.manager_balances, 
      auction::account_address(account)
    );

    let amount_x = balance::value(&manager_balance.balance_x);
    let amount_y = balance::value(&manager_balance.balance_y);

    (
      coin::take(&mut manager_balance.balance_x, amount_x, ctx),
      coin::take(&mut manager_balance.balance_y, amount_y, ctx)
    )
  }

  // === Flash Loans ===

  public fun flash_loan<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    amount_x: u64,
    amount_y: u64,
    ctx: &mut TxContext
  ): (Invoice, Coin<CoinX>, Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    
    assert!(!pool_state.locked, errors::pool_is_locked());
    
    pool_state.locked = true;

    let (balance_x, balance_y, _) = amounts(pool_state);

    let prev_k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

    assert!(balance_x >= amount_x && balance_y >= amount_y, errors::not_enough_funds_to_lend());

    let coin_x = coin::take(&mut pool_state.balance_x, amount_x, ctx);
    let coin_y = coin::take(&mut pool_state.balance_y, amount_y, ctx);

    let invoice = Invoice { 
      pool_address: object::uid_to_address(&pool.id),  
      repay_amount_x: amount_x + (mul_div_up((amount_x as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
      repay_amount_y: amount_y + (mul_div_up((amount_y as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
      prev_k
    };
    
    (invoice, coin_x, coin_y)
  }  

  public fun repay_flash_loan<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    invoice: Invoice,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>
  ) {
   let Invoice { pool_address, repay_amount_x, repay_amount_y, prev_k } = invoice;
   
   assert!(object::uid_to_address(&pool.id) == pool_address, errors::wrong_pool());
   assert!(coin::value(&coin_x) >= repay_amount_x, errors::wrong_repay_amount());
   assert!(coin::value(&coin_y) >= repay_amount_y, errors::wrong_repay_amount());
   
   let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

   coin::put(&mut pool_state.balance_x, coin_x);
   coin::put(&mut pool_state.balance_y, coin_y);

   let (balance_x, balance_y, _) = amounts(pool_state);

   let k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

   assert!(k > prev_k, errors::invalid_invariant());
    
   pool_state.locked = false;
  }    

  // === Public-View Functions ===

  public fun pools(registry: &Registry): &Table<TypeName, address> {
    &registry.pools
  }

  public fun pool_address<Curve, CoinX, CoinY>(registry: &Registry): Option<address> {
    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    if (table::contains(&registry.pools, registry_key))
      option::some(*table::borrow(&registry.pools, registry_key))
    else
      option::none()
  }

  public fun exists_<Curve, CoinX, CoinY>(registry: &Registry): bool {
    table::contains(&registry.pools, type_name::get<RegistryKey<Curve, CoinX, CoinY>>())   
  }

  public fun lp_coin_supply<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::supply_value(coin::supply_immut(&pool_state.lp_coin_cap))  
  }

  public fun balance_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_x)
  }

  public fun balance_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_y)
  }

  public fun decimals_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_x
  }

  public fun decimals_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_y
  }

  public fun stable<CoinX, CoinY, LpCoin>(pool: &InterestPool): bool {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    !pool_state.volatile
  }

  public fun volatile<CoinX, CoinY, LpCoin>(pool: &InterestPool): bool {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.volatile
  }

  public fun fees<CoinX, CoinY, LpCoin>(pool: &InterestPool): Fees {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.fees
  }

  public fun locked<CoinX, CoinY, LpCoin>(pool: &InterestPool): bool {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.locked
  }

  public fun admin_balance_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.admin_balance_x)
  }

  public fun admin_balance_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.admin_balance_y)
  }

  public fun repay_amount_x(invoice: &Invoice): u64 {
    invoice.repay_amount_x
  }

  public fun repay_amount_y(invoice: &Invoice): u64 {
    invoice.repay_amount_y
  }

  public fun previous_k(invoice: &Invoice): u256 {
    invoice.prev_k
  }  

  public fun manager_address<CoinX, CoinY, LpCoin>(pool: &InterestPool, clock: &Clock): Option<address> {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);

    if (are_manager_fees_active_impl(pool_state, clock)) option::some(pool_state.manager.address) else option::none()
  }

  public fun manager_start<CoinX, CoinY, LpCoin>(pool: &InterestPool, clock: &Clock): Option<u64> {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);

    if (are_manager_fees_active_impl(pool_state, clock)) option::some(pool_state.manager.start) else option::none() 
  }

  public fun manager_end<CoinX, CoinY, LpCoin>(pool: &InterestPool, clock: &Clock): Option<u64> {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);

    if (are_manager_fees_active_impl(pool_state, clock)) option::some(pool_state.manager.end) else option::none()
  }

  public fun manager_fees<CoinX, CoinY, LpCoin>(pool: &InterestPool, clock: &Clock): Option<Fees> {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);

    if (are_manager_fees_active_impl(pool_state, clock)) option::some(pool_state.manager.fees) else option::none()
  }

  public fun are_manager_fees_active<CoinX, CoinY, LpCoin>(pool: &InterestPool, clock: &Clock): bool {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);

    are_manager_fees_active_impl(pool_state, clock)
  }

  // === Admin Functions ===

  public fun update_fees<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &mut InterestPool,
    fee_in_percent: Option<u256>,
    fee_out_percent: Option<u256>, 
    admin_fee_percent: Option<u256>,  
  ) {
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    fees::update_fee_in_percent(&mut pool_state.fees, fee_in_percent);
    fees::update_fee_out_percent(&mut pool_state.fees, fee_out_percent);  
    fees::update_admin_fee_percent(&mut pool_state.fees, admin_fee_percent);

    events::update_fees(pool_address, pool_state.fees);
  }

  public fun take_fees<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &mut InterestPool,
    ctx: &mut TxContext
  ): (Coin<LpCoin>, Coin<CoinX>, Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    let amount_lp_coin = balance::value(&pool_state.admin_lp_coin_balance);
    let amount_x = balance::value(&pool_state.admin_balance_x);
    let amount_y = balance::value(&pool_state.admin_balance_y);

    (
      coin::take(&mut pool_state.admin_lp_coin_balance, amount_lp_coin, ctx),
      coin::take(&mut pool_state.admin_balance_x, amount_x, ctx),
      coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
    )
  }

  public fun update_name<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    name: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_name(&pool_state.lp_coin_cap, metadata, name);  
  }

  public fun update_symbol<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    symbol: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_symbol(&pool_state.lp_coin_cap, metadata, symbol);
  }

  public fun update_description<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    description: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_description(&pool_state.lp_coin_cap, metadata, description);
  }

  public fun update_icon_url<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    url: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_icon_url(&pool_state.lp_coin_cap, metadata, url);
  }  

  // === Private Functions ===    

  fun new_pool_internal<Curve, CoinX, CoinY, LpCoin>(
    registry: &mut Registry,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>,
    lp_coin_cap: TreasuryCap<LpCoin>,
    decimals_x: u64,
    decimals_y: u64,
    volatile: bool,
    ctx: &mut TxContext
  ): Coin<LpCoin> {
    assert!(
      balance::supply_value(coin::supply_immut(&lp_coin_cap)) == 0, 
      errors::supply_must_have_zero_value()
    );

    let coin_x_value = coin::value(&coin_x);
    let coin_y_value = coin::value(&coin_y);

    assert!(coin_x_value != 0 && coin_y_value != 0, errors::provide_both_coins());

    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    assert!(!table::contains(&registry.pools, registry_key), errors::pool_already_deployed());

    let shares = (sqrt_down(((coin_x_value as u256) * (coin_y_value as u256))) as u64);

    let seed_liquidity = balance::increase_supply(
      coin::supply_mut(&mut lp_coin_cap), 
      MINIMUM_LIQUIDITY
    );
    
    let sender_balance = coin::mint(&mut lp_coin_cap, shares, ctx);

    let pool_state = PoolState {
      lp_coin_cap,
      balance_x: coin::into_balance(coin_x),
      balance_y: coin::into_balance(coin_y),
      decimals_x,
      decimals_y,
      volatile,
      seed_liquidity,
      fees: new_fees<Curve>(),
      locked: false,
      admin_balance_x: balance::zero(),
      admin_balance_y: balance::zero(),
      manager: Manager {
        address: @0x0,
        start: 0,
        end: 0,
        fees: new_fees<Curve>(),
      },
      manager_balances: table::new(ctx),
      admin_lp_coin_balance: balance::zero()
    };

    let pool = InterestPool {
      id: object::new(ctx)
    };

    let pool_address = object::uid_to_address(&pool.id);

    df::add(&mut pool.id, PoolStateKey {}, pool_state);

    table::add(&mut registry.pools, registry_key, object::uid_to_address(&pool.id));

    events::new_pool<Curve, CoinX, CoinY>(pool_address, coin_x_value, coin_y_value);

    share_object(pool);
    auction::new_auction<LpCoin>(pool_address, ctx);
    
    sender_balance
  }

  fun swap_coin_x<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    clock: &Clock,
    coin_x: Coin<CoinX>,
    coin_y_min_value: u64,
    ctx: &mut TxContext
  ): Coin<CoinY> {
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_x);
    let is_manager_fee_active = are_manager_fees_active_impl(pool_state, clock);
    
    let swap_amount = swap_amounts(
      pool_state, 
      coin_in_amount, 
      coin_y_min_value, 
      true,
      is_manager_fee_active
      );

    if (swap_amount.admin_fee_in != 0) {
      balance::join(&mut pool_state.admin_balance_x, coin::into_balance(coin::split(&mut coin_x, swap_amount.admin_fee_in, ctx)));
    };

    if (swap_amount.admin_fee_out != 0) {
      balance::join(&mut pool_state.admin_balance_y, balance::split(&mut pool_state.balance_y, swap_amount.admin_fee_out));  
    };

    if (swap_amount.manager_fee_in != 0) {
      balance::join(
        &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_x, 
        coin::into_balance(coin::split(&mut coin_x, swap_amount.manager_fee_in, ctx))
      );
    };

    if (swap_amount.manager_fee_out != 0) {
      balance::join(
        &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_y, 
        balance::split(&mut pool_state.balance_y, swap_amount.manager_fee_out)
      );  
    };

    balance::join(&mut pool_state.balance_x, coin::into_balance(coin_x));

    events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount.amount_out, swap_amount);

    coin::take(&mut pool_state.balance_y, swap_amount.amount_out, ctx) 
  }

  fun swap_coin_y<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    clock: &Clock,
    coin_y: Coin<CoinY>,
    coin_x_min_value: u64,
    ctx: &mut TxContext
  ): Coin<CoinX> {
    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_y);
    let is_manager_fee_active = are_manager_fees_active_impl(pool_state, clock);

    let swap_amount = swap_amounts(
      pool_state, 
      coin_in_amount, 
      coin_x_min_value, 
      false,
      is_manager_fee_active
    );

    if (swap_amount.admin_fee_in != 0) {
      balance::join(&mut pool_state.admin_balance_y, coin::into_balance(coin::split(&mut coin_y, swap_amount.admin_fee_in, ctx)));
    };

    if (swap_amount.admin_fee_out != 0) {
      balance::join(&mut pool_state.admin_balance_x, balance::split(&mut pool_state.balance_x, swap_amount.admin_fee_out)); 
    };

    if (swap_amount.manager_fee_in != 0) {
      balance::join(
        &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_y, 
        coin::into_balance(coin::split(&mut coin_y, swap_amount.manager_fee_in, ctx))
      );
    };

    if (swap_amount.manager_fee_out != 0) {
      balance::join(
        &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_x, 
        balance::split(&mut pool_state.balance_x, swap_amount.manager_fee_out)
      );  
    };

    balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));

    events::swap<CoinY, CoinX, SwapAmount>(pool_address, coin_in_amount, swap_amount.amount_out, swap_amount);

    coin::take(&mut pool_state.balance_x, swap_amount.amount_out, ctx) 
  }  

  fun new_fees<Curve>(): Fees {
    if (curves::is_volatile<Curve>())
      fees::new(INITIAL_VOLATILE_FEE_PERCENT, INITIAL_VOLATILE_FEE_PERCENT, INITIAL_ADMIN_FEE)
    else
      fees::new(INITIAL_STABLE_FEE_PERCENT, INITIAL_STABLE_FEE_PERCENT, INITIAL_ADMIN_FEE)
  }

  fun amounts<CoinX, CoinY, LpCoin>(state: &PoolState<CoinX, CoinY, LpCoin>): (u64, u64, u64) {
    ( 
      balance::value(&state.balance_x), 
      balance::value(&state.balance_y),
      balance::supply_value(coin::supply_immut(&state.lp_coin_cap))
    )
  }

  fun swap_amounts<CoinX, CoinY, LpCoin>(
    pool_state: &PoolState<CoinX, CoinY, LpCoin>,
    coin_in_amount: u64,
    coin_out_min_value: u64,
    is_x: bool,
    is_manager_active: bool 
  ): SwapAmount {
    let (balance_x, balance_y, _) = amounts(pool_state);

    let prev_k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

    let standard_fee_in = if (!is_manager_active) fees::get_fee_in_amount(&pool_state.fees, coin_in_amount) else 0;
    let admin_fee_in = if (!is_manager_active) fees::get_admin_amount(&pool_state.fees, standard_fee_in) else 0;
    let manager_fee_in = if (!is_manager_active) 0 else fees::get_fee_in_amount(&pool_state.manager.fees, coin_in_amount);

    let coin_in_amount = coin_in_amount - standard_fee_in - manager_fee_in;

    let amount_out = if (pool_state.volatile) {
      if (is_x) 
        volatile::get_amount_out(coin_in_amount, balance_x, balance_y)
      else 
        volatile::get_amount_out(coin_in_amount, balance_y, balance_x)
    } else {
        stable::get_amount_out(
          coin_in_amount, 
          balance_x, 
          balance_y, 
          pool_state.decimals_x, 
          pool_state.decimals_y, 
          is_x
        )
    };

    let standard_fee_out = if (!is_manager_active) fees::get_fee_out_amount(&pool_state.fees, amount_out) else 0;
    let admin_fee_out = if (!is_manager_active) fees::get_admin_amount(&pool_state.fees, standard_fee_out) else 0;
    let manager_fee_out = if (!is_manager_active) 0 else fees::get_fee_out_amount(&pool_state.manager.fees, amount_out);

    let amount_out = amount_out - standard_fee_out - manager_fee_out;

    assert!(amount_out >= coin_out_min_value, errors::slippage());

    let new_k = if (pool_state.volatile) {
      if (is_x)
        volatile::invariant_(balance_x + coin_in_amount + standard_fee_in - admin_fee_in - manager_fee_in, balance_y - amount_out - admin_fee_out - manager_fee_out)
      else
        volatile::invariant_(balance_x - amount_out - admin_fee_out - manager_fee_out, balance_y + coin_in_amount + standard_fee_in - admin_fee_in - manager_fee_in)
    } else {
      if (is_x) 
        stable::invariant_(balance_x + coin_in_amount + standard_fee_in - admin_fee_in - manager_fee_in, balance_y - amount_out - admin_fee_out - manager_fee_out, pool_state.decimals_x, pool_state.decimals_y)
      else
        stable::invariant_(balance_x - amount_out - admin_fee_out - manager_fee_out, balance_y + standard_fee_in + coin_in_amount - admin_fee_in - manager_fee_in, pool_state.decimals_x, pool_state.decimals_y)
    };

    assert!(new_k >= prev_k, errors::invalid_invariant());

    SwapAmount {
      amount_out,
      standard_fee_in,
      standard_fee_out,
      admin_fee_in,
      admin_fee_out,
      manager_fee_in,
      manager_fee_out,
    }  
  }

  fun add_manager_fee_x<CoinX, CoinY, LpCoin>(pool_state: &mut PoolState<CoinX, CoinY, LpCoin>, coin_x: Coin<CoinX>) {
    if (!table::contains(&pool_state.manager_balances, pool_state.manager.address)) {
      table::add(
        &mut pool_state.manager_balances, 
        pool_state.manager.address, 
        ManagerBalances {
          balance_x: balance::zero(),
          balance_y: balance::zero()
        } 
      )
    };

    balance::join(
      &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_x, 
      coin::into_balance(coin_x)
    );
  }

  fun add_manager_fee_y<CoinX, CoinY, LpCoin>(pool_state: &mut PoolState<CoinX, CoinY, LpCoin>, coin_y: Coin<CoinY>) {
    if (!table::contains(&pool_state.manager_balances, pool_state.manager.address)) {
      table::add(
        &mut pool_state.manager_balances, 
        pool_state.manager.address, 
        ManagerBalances {
          balance_x: balance::zero(),
          balance_y: balance::zero()
        } 
      )
    };

    balance::join(
      &mut table::borrow_mut(&mut pool_state.manager_balances, pool_state.manager.address).balance_y, 
      coin::into_balance(coin_y)
    );
  }

  fun are_manager_fees_active_impl<CoinX, CoinY, LpCoin>(pool_state: &PoolState<CoinX, CoinY, LpCoin>, clock: &Clock): bool {
    let current_timestamp = clock_timestamp_s(clock);
    current_timestamp >= pool_state.manager.start && pool_state.manager.end > current_timestamp
  }

  fun clock_timestamp_s(clock: &Clock): u64 {
    clock::timestamp_ms(clock) / 1000
  }

  fun pool_state<CoinX, CoinY, LpCoin>(pool: &InterestPool): &PoolState<CoinX, CoinY, LpCoin> {
    df::borrow(&pool.id, PoolStateKey {})
  }

  fun pool_state_mut<CoinX, CoinY, LpCoin>(pool: &mut InterestPool): &mut PoolState<CoinX, CoinY, LpCoin> {
    df::borrow_mut(&mut pool.id, PoolStateKey {})
  }

  // === Test Functions ===
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }

  #[test_only]
  public fun seed_liquidity<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.seed_liquidity)
  }
}