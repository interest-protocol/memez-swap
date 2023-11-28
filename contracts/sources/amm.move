module sc_dex::sui_coins_amm {
  use std::ascii;
  use std::string;
  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};

  use sc_dex::utils;
  use sc_dex::errors;
  use sc_dex::stable;
  use sc_dex::events;
  use sc_dex::volatile; 
  use sc_dex::admin::Admin;
  use sc_dex::fees::{Self, Fees};
  use sc_dex::math64::{min, mul_div_down}; 
  use sc_dex::math256::{sqrt_down, mul_div_up};
  use sc_dex::curves::{Self, Volatile, Stable};

  const PRECISION: u256 = 1_000_000_000_000_000_000;
  const MINIMUM_LIQUIDITY: u64 = 100;
  const INITIAL_STABLE_FEE_PERCENT: u256 = 250_000_000_000_000; // 0.025%
  const INITIAL_VOLATILE_FEE_PERCENT: u256 = 3_000_000_000_000_000; // 0.3%
  const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%
  const FLASH_LOAN_FEE_PERCENT: u256 = 5_000_000_000_000_000; //0.5% 

  struct Registry has key {
    id: UID,
    pools: Table<TypeName, ID>
  }
  
  struct SuiCoinsPool has key {
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
    fees: Fees,
    volatile: bool,
    locked: bool     
  } 

  struct Invoice {
    pool_id: ID,
    repay_amount_x: u64,
    repay_amount_y: u64,
    prev_k: u256
  }

  #[allow(unused_function)]
  fun init(ctx: &mut TxContext) {
    share_object(
      Registry {
        id: object::new(ctx),
        pools: table::new(ctx)
      }
    );
  }  

  // === View Functions ===

  public fun borrow_pools(registry: &Registry): &Table<TypeName, ID> {
    &registry.pools
  }

  public fun pool_id<Curve, CoinX, CoinY>(registry: &Registry): Option<ID> {
    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    if (table::contains(&registry.pools, registry_key))
      option::some(*table::borrow(&registry.pools, registry_key))
    else
      option::none()
  }

  public fun exists_<Curve, CoinX, CoinY>(registry: &Registry): bool {
    table::contains(&registry.pools, type_name::get<RegistryKey<Curve, CoinX, CoinY>>())   
  }

  public fun lp_coin_supply<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::supply_value(coin::supply_immut(&pool_state.lp_coin_cap))  
  }

  public fun balance_x<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_x)
  }

  public fun balance_y<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_y)
  }

  public fun decimals_x<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_x
  }

  public fun decimals_y<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_y
  }

  public fun stable<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): bool {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    !pool_state.volatile
  }

  public fun volatile<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): bool {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.volatile
  }

  public fun fees<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): Fees {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.fees
  }

  public fun locked<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): bool {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.locked
  }

  public fun admin_balance_x<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.admin_balance_x)
  }

  public fun admin_balance_y<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
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

  // === Mutative Functions ===  

  public fun new_pool<CoinX, CoinY, LpCoin>(
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
    pool: &mut SuiCoinsPool, 
    coin_in: Coin<CoinIn>,
    coin_min_value: u64,
    ctx: &mut TxContext    
  ): Coin<CoinOut> {
    assert!(coin::value(&coin_in) != 0, errors::no_zero_coin());

    if (utils::is_coin_x<CoinIn, CoinOut>()) 
      swap_coin_x<CoinIn, CoinOut, LpCoin>(pool, coin_in, coin_min_value, ctx)
    else 
      swap_coin_y<CoinOut, CoinIn, LpCoin>(pool, coin_in, coin_min_value, ctx)
  }

  public fun add_liquidity<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>,
    lp_coin_min_amount: u64,
    ctx: &mut TxContext 
  ): (Coin<LpCoin>, Coin<CoinX>, Coin<CoinY>) {
    let coin_x_value = coin::value(&coin_x);
    let coin_y_value = coin::value(&coin_y);       

    assert!(coin_x_value != 0 && coin_y_value != 0, errors::provide_both_coins());

    let pool_id = object::id(pool);
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let (balance_x, balance_y, lp_coin_supply) = get_amounts(pool_state);

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

    events::add_liquidity<CoinX, CoinY>(pool_id, optimal_x_amount, optimal_y_amount, shares_to_mint);

    (coin::from_balance(balance::increase_supply(coin::supply_mut(&mut pool_state.lp_coin_cap), shares_to_mint), ctx), extra_x, extra_y)
  }

  public fun remove_liquidity<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    lp_coin: Coin<LpCoin>,
    coin_x_min_amount: u64,
    coin_y_min_amount: u64,
    ctx: &mut TxContext
  ): (Coin<CoinX>, Coin<CoinY>) {
    let lp_coin_value = coin::value(&lp_coin);

    assert!(lp_coin_value != 0, errors::no_zero_coin());
    
    let pool_id = object::id(pool);
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let (balance_x, balance_y, lp_coin_supply) = get_amounts(pool_state);

    let coin_x_removed = mul_div_down(lp_coin_value, balance_x, lp_coin_supply);
    let coin_y_removed = mul_div_down(lp_coin_value, balance_y, lp_coin_supply);

    assert!(coin_x_removed >= coin_x_min_amount, errors::slippage());
    assert!(coin_y_removed >= coin_y_min_amount, errors::slippage());

    balance::decrease_supply(coin::supply_mut(&mut pool_state.lp_coin_cap), coin::into_balance(lp_coin));

    events::remove_liquidity<CoinX, CoinY>(pool_id, coin_x_removed, coin_y_removed, lp_coin_value);

    (
      coin::take(&mut pool_state.balance_x, coin_x_removed, ctx),
      coin::take(&mut pool_state.balance_y, coin_y_removed, ctx)
    )
  }  

  // === Flash Loan ===

  public fun flash_loan<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    amount_x: u64,
    amount_y: u64,
    ctx: &mut TxContext
  ): (Invoice, Coin<CoinX>, Coin<CoinY>) {
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);
    
    assert!(!pool_state.locked, errors::pool_is_locked());
    
    pool_state.locked = true;

    let (balance_x, balance_y, _) = get_amounts(pool_state);

    let prev_k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

    assert!(balance_x >= amount_x && balance_y >= amount_y, errors::not_enough_funds_to_lend());

    let coin_x = coin::take(&mut pool_state.balance_x, amount_x, ctx);
    let coin_y = coin::take(&mut pool_state.balance_y, amount_y, ctx);

    let invoice = Invoice { 
      pool_id: object::id(pool),  
      repay_amount_x: amount_x + (mul_div_up((amount_x as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
      repay_amount_y: amount_y + (mul_div_up((amount_y as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
      prev_k
    };
    
    (invoice, coin_x, coin_y)
  }  

  public fun repay_flash_loan<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    invoice: Invoice,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>
  ) {
   let Invoice { pool_id, repay_amount_x, repay_amount_y, prev_k } = invoice;
   
   assert!(object::id(pool) == pool_id, errors::wrong_pool());
   assert!(coin::value(&coin_x) >= repay_amount_x, errors::wrong_repay_amount());
   assert!(coin::value(&coin_y) >= repay_amount_y, errors::wrong_repay_amount());
   
   let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);

   coin::put(&mut pool_state.balance_x, coin_x);
   coin::put(&mut pool_state.balance_y, coin_y);

   let (balance_x, balance_y, _) = get_amounts(pool_state);

   let k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

   assert!(k > prev_k, errors::invalid_invariant());
    
   pool_state.locked = false;
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
      admin_balance_y: balance::zero()
    };

    let pool = SuiCoinsPool {
      id: object::new(ctx)
    };

    df::add(&mut pool.id, PoolStateKey {}, pool_state);

    table::add(&mut registry.pools, registry_key, object::id(&pool));

    events::new_pool<Curve, CoinX, CoinY>(object::id(&pool), coin_x_value, coin_y_value);

    share_object(pool);

    sender_balance
  }

  fun swap_coin_x<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    coin_x: Coin<CoinX>,
    coin_y_min_value: u64,
    ctx: &mut TxContext
  ): Coin<CoinY> {
    let pool_id = object::id(pool);
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_x);
    
    let (amount_out, fee_x, fee_y) = swap_amounts(pool_state, coin_in_amount, coin_y_min_value, true);

    if (fee_x != 0) {
      balance::join(&mut pool_state.admin_balance_x, coin::into_balance(coin::split(&mut coin_x, fee_x, ctx)));
    };

    if (fee_y != 0) {
      balance::join(&mut pool_state.admin_balance_y, balance::split(&mut pool_state.balance_y, fee_y));  
    };

    balance::join(&mut pool_state.balance_x, coin::into_balance(coin_x));

    events::swap<CoinX, CoinY>(pool_id, coin_in_amount, amount_out, fee_x, fee_y);

    coin::take(&mut pool_state.balance_y, amount_out, ctx) 
  }

  fun swap_coin_y<CoinX, CoinY, LpCoin>(
    pool: &mut SuiCoinsPool,
    coin_y: Coin<CoinY>,
    coin_x_min_value: u64,
    ctx: &mut TxContext
  ): Coin<CoinX> {
    let pool_id = object::id(pool);
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_y);

    let (amount_out, fee_y, fee_x) = swap_amounts(pool_state, coin_in_amount, coin_x_min_value, false);

    if (fee_y != 0) {
      balance::join(&mut pool_state.admin_balance_y, coin::into_balance(coin::split(&mut coin_y, fee_y, ctx)));
    };

    if (fee_x != 0) {
      balance::join(&mut pool_state.admin_balance_x, balance::split(&mut pool_state.balance_x, fee_x)); 
    };

    balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));

    events::swap<CoinY, CoinX>(pool_id, coin_in_amount, amount_out, fee_y, fee_x);

    coin::take(&mut pool_state.balance_x, amount_out, ctx) 
  }  

  fun new_fees<Curve>(): Fees {
    if (curves::is_volatile<Curve>())
      fees::new(INITIAL_VOLATILE_FEE_PERCENT, INITIAL_VOLATILE_FEE_PERCENT, INITIAL_ADMIN_FEE)
    else
      fees::new(INITIAL_STABLE_FEE_PERCENT, INITIAL_STABLE_FEE_PERCENT, INITIAL_ADMIN_FEE)
  }

  fun get_amounts<CoinX, CoinY, LpCoin>(state: &PoolState<CoinX, CoinY, LpCoin>): (u64, u64, u64) {
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
    is_x: bool 
  ): (u64, u64, u64) {
    let (balance_x, balance_y, _) = get_amounts(pool_state);

    let prev_k = if (pool_state.volatile) 
      volatile::invariant_(balance_x, balance_y) 
    else 
      stable::invariant_(balance_x, balance_y, pool_state.decimals_x, pool_state.decimals_y);

    let fee_in = fees::get_fee_in_amount(&pool_state.fees, coin_in_amount);
    let admin_fee_in = fees::get_admin_amount(&pool_state.fees, fee_in);

    let coin_in_amount = coin_in_amount - fee_in;

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

    let fee_out = fees::get_fee_out_amount(&pool_state.fees, amount_out);
    let admin_fee_out = fees::get_admin_amount(&pool_state.fees, fee_out);

    let amount_out = amount_out - fee_out;

    assert!(amount_out >= coin_out_min_value, errors::slippage());

    let new_k = if (pool_state.volatile) {
      if (is_x)
        volatile::invariant_(balance_x + coin_in_amount + fee_in - admin_fee_in, balance_y - amount_out - admin_fee_out)
      else
        volatile::invariant_(balance_x - amount_out - admin_fee_out, balance_y + coin_in_amount + fee_in - admin_fee_in)
    } else {
      if (is_x) 
        stable::invariant_(balance_x + coin_in_amount + fee_in - admin_fee_in, balance_y - amount_out - admin_fee_out, pool_state.decimals_x, pool_state.decimals_y)
      else
        stable::invariant_(balance_x - amount_out - admin_fee_out, balance_y + fee_in + coin_in_amount - admin_fee_in, pool_state.decimals_x, pool_state.decimals_y)
    };

    assert!(new_k >= prev_k, errors::invalid_invariant());

    (amount_out, admin_fee_in, admin_fee_out)    
  }

  fun borrow_pool_state<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): &PoolState<CoinX, CoinY, LpCoin> {
    df::borrow(&pool.id, PoolStateKey {})
  }

  fun borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool: &mut SuiCoinsPool): &mut PoolState<CoinX, CoinY, LpCoin> {
    df::borrow_mut(&mut pool.id, PoolStateKey {})
  }

  // === Admin ===

  public fun update_fee<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &mut SuiCoinsPool,
    fee_in_percent: Option<u256>,
    fee_out_percent: Option<u256>, 
    admin_fee_percent: Option<u256>,  
  ) {
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);

    fees::update_fee_in_percent(&mut pool_state.fees, fee_in_percent);
    fees::update_fee_out_percent(&mut pool_state.fees, fee_out_percent);  
    fees::update_admin_fee_percent(&mut pool_state.fees, admin_fee_percent);
  }

  public fun take_fees<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &mut SuiCoinsPool,
    ctx: &mut TxContext
  ): (Coin<CoinX>, Coin<CoinY>) {
    let pool_state = borrow_mut_pool_state<CoinX, CoinY, LpCoin>(pool);

    let amount_x = balance::value(&pool_state.admin_balance_x);
    let amount_y = balance::value(&pool_state.admin_balance_y);

    (
      coin::take(&mut pool_state.admin_balance_x, amount_x, ctx),
      coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
    )
  }

  public fun update_name<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &SuiCoinsPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    name: string::String
  ) {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_name(&pool_state.lp_coin_cap, metadata, name);  
  }

  public fun update_symbol<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &SuiCoinsPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    symbol: ascii::String
  ) {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_symbol(&pool_state.lp_coin_cap, metadata, symbol);
  }

  public fun update_description<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &SuiCoinsPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    description: string::String
  ) {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_description(&pool_state.lp_coin_cap, metadata, description);
  }

  public fun update_icon_url<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &SuiCoinsPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    url: ascii::String
  ) {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_icon_url(&pool_state.lp_coin_cap, metadata, url);
  }

  // === Test Only Functions ===
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }

  #[test_only]
  public fun seed_liquidity<CoinX, CoinY, LpCoin>(pool: &SuiCoinsPool): u64 {
    let pool_state = borrow_pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.seed_liquidity)
  }
}