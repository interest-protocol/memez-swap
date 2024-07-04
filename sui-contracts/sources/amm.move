module amm::interest_amm {
    // === Imports ===
  
    use std::type_name::{Self, TypeName};

    use sui::{
        coin::Coin,
        dynamic_field as df,
        table::{Self, Table},
        transfer::share_object,
        balance::{Self, Balance},
    };

    use suitears::math256::mul_div_up; 

    use amm::{
        interest_amm_admin::Admin,
        interest_amm_utils as utils,
        interest_amm_errors as errors,
        interest_amm_events as events,
        interest_amm_fees::{Self as fees, Fees},    
        interest_amm_invariant::{invariant_, get_amount_out},
    };

    // === Constants ===
    const PRECISION: u256 = 1_000_000_000_000_000_000;
    const INITIAL_VOLATILE_FEE_PERCENT: u256 = 3_000_000_000_000_000; // 0.3%
    const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%
    const FLASH_LOAN_FEE_PERCENT: u256 = 5_000_000_000_000_000; //0.5% 

    // === Structs ===

    public struct Registry has key {
        id: UID,
        pools: Table<TypeName, address>
    }
  
    public struct InterestPool has key {
        id: UID 
    }

    public struct RegistryKey<phantom CoinX, phantom CoinY> has drop {}

    public struct PoolStateKey has drop, copy, store {}

    public struct PoolState<phantom CoinX, phantom CoinY> has store {
        balance_x: Balance<CoinX>,
        balance_y: Balance<CoinY>,
        creator_balance_x: Balance<CoinX>,
        creator_balance_y: Balance<CoinY>,
        admin_balance_x: Balance<CoinX>,
        admin_balance_y: Balance<CoinY>,
        fees: Fees,
        locked: bool
    } 

    // TODO - can set fees and lock add_liquidity
    public struct Deployer has key, store {
        id: UID,
        pool: address
    }

    public struct SwapAmount has store, drop, copy {
        amount_out: u64,
        admin_fee_in: u64,
        admin_fee_out: u64,
        standard_fee_in: u64,
        standard_fee_out: u64,
    }

    public struct Invoice {
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
                pools: table::new(ctx),
            }
        );
    }  

    // === DEX ===

    #[lint_allow(share_owned)]
    public fun new<CoinX, CoinY>(
        registry: &mut Registry,
        coin_x: Coin<CoinX>,
        coin_y: Coin<CoinY>,
        ctx: &mut TxContext    
    ) {
        new_pool_internal<CoinX, CoinY>(registry, coin_x, coin_y, ctx);
    }

    public fun swap<CoinIn, CoinOut>(
        pool: &mut InterestPool, 
        coin_in: Coin<CoinIn>,
        coin_min_value: u64,
        ctx: &mut TxContext    
    ): Coin<CoinOut> {
        assert!(coin_in.value() != 0, errors::no_zero_coin());

        if (utils::is_coin_x<CoinIn, CoinOut>()) 
            swap_coin_x<CoinIn, CoinOut>(pool, coin_in, coin_min_value, ctx)
        else 
            swap_coin_y<CoinOut, CoinIn>(pool, coin_in, coin_min_value, ctx)
    }

    // === Flash Loans ===

    public fun flash_loan<CoinX, CoinY>(
        pool: &mut InterestPool,
        amount_x: u64,
        amount_y: u64,
        ctx: &mut TxContext
    ): (Invoice, Coin<CoinX>, Coin<CoinY>) {
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);
    
        assert!(!pool_state.locked, errors::pool_is_locked());
    
        pool_state.locked = true;

        let (balance_x, balance_y) = amounts(pool_state);

        let prev_k = invariant_(balance_x, balance_y);

        assert!(balance_x >= amount_x && balance_y >= amount_y, errors::not_enough_funds_to_lend());

        let coin_x = pool_state.balance_x.split(amount_x).into_coin(ctx);
        let coin_y = pool_state.balance_y.split(amount_y).into_coin(ctx);

        let invoice = Invoice { 
            pool_address: pool.id.uid_to_address(),  
            repay_amount_x: amount_x + (mul_div_up((amount_x as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
            repay_amount_y: amount_y + (mul_div_up((amount_y as u256), FLASH_LOAN_FEE_PERCENT, PRECISION) as u64),
            prev_k
        };
    
        (invoice, coin_x, coin_y)
    }  

    public fun repay_flash_loan<CoinX, CoinY>(
        pool: &mut InterestPool,
        invoice: Invoice,
        coin_x: Coin<CoinX>,
        coin_y: Coin<CoinY>
    ) {
        let Invoice { pool_address, repay_amount_x, repay_amount_y, prev_k } = invoice;
   
        assert!(pool.id.uid_to_address() == pool_address, errors::wrong_pool());
        assert!(coin_x.value() >= repay_amount_x, errors::wrong_repay_amount());
        assert!(coin_y.value() >= repay_amount_y, errors::wrong_repay_amount());
   
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        pool_state.balance_x.join(coin_x.into_balance());
        pool_state.balance_y.join(coin_y.into_balance());

        let (balance_x, balance_y) = amounts(pool_state);

        let k = invariant_(balance_x, balance_y);

        assert!(k > prev_k, errors::invalid_invariant());
    
        pool_state.locked = false;
    }    

    // === Public-View Functions ===

    public fun pools(registry: &Registry): &Table<TypeName, address> {
        &registry.pools
    }

    public fun pool_address<CoinX, CoinY>(registry: &Registry): Option<address> {
        let registry_key = type_name::get<RegistryKey<CoinX, CoinY>>();

        if (registry.pools.contains(registry_key))
            option::some(*registry.pools.borrow(registry_key))
        else
            option::none()
    }

    public fun pool_address_from_lp_coin<LpCoin>(registry: &Registry): Option<address> {
        let lp_coin_key = type_name::get<LpCoin>();

        if (registry.pools.contains(lp_coin_key))
            option::some(*registry.pools.borrow(lp_coin_key))
        else
        option::none()
    }

    public fun exists_<CoinX, CoinY>(registry: &Registry): bool {
        registry.pools.contains(type_name::get<RegistryKey<CoinX, CoinY>>())   
    }

    public fun balance_x<CoinX, CoinY>(pool: &InterestPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.balance_x.value()
    }

    public fun balance_y<CoinX, CoinY>(pool: &InterestPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.balance_y.value()
    }

    public fun fees<CoinX, CoinY>(pool: &InterestPool): Fees {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.fees
    }

    public fun locked<CoinX, CoinY>(pool: &InterestPool): bool {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.locked
    }

    public fun admin_balance_x<CoinX, CoinY>(pool: &InterestPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.admin_balance_x.value()
    }

    public fun admin_balance_y<CoinX, CoinY>(pool: &InterestPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.admin_balance_y.value()
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

    // === Admin Functions ===

    public fun update_fees<CoinX, CoinY>(
        _: &Admin,
        pool: &mut InterestPool,
        fee_in_percent: Option<u256>,
        fee_out_percent: Option<u256>, 
        admin_fee_percent: Option<u256>,  
    ) {
        let pool_address = pool.id.uid_to_address();
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        pool_state.fees.update_fee_in_percent(fee_in_percent);
        pool_state.fees.update_fee_out_percent(fee_out_percent);  
        pool_state.fees.update_admin_fee_percent(admin_fee_percent);

        events::update_fees(pool_address, pool_state.fees);
    }

    public fun take_fees<CoinX, CoinY>(
        _: &Admin,
        pool: &mut InterestPool,
        ctx: &mut TxContext
    ): (Coin<CoinX>, Coin<CoinY>) {
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        (
            pool_state.admin_balance_x.withdraw_all().into_coin(ctx),
            pool_state.admin_balance_y.withdraw_all().into_coin(ctx),    
        )
    }

    // === Private Functions ===    

    fun new_pool_internal<CoinX, CoinY>(
        registry: &mut Registry,
        coin_x: Coin<CoinX>,
        coin_y: Coin<CoinY>,
        ctx: &mut TxContext
    ) {
        assert!(utils::are_coins_ordered<CoinX, CoinY>(), errors::coins_must_be_ordered());
        let coin_x_value = coin_x.value();
        let coin_y_value = coin_y.value();

        assert!(coin_x_value != 0 && coin_y_value != 0, errors::provide_both_coins());

        let registry_key = type_name::get<RegistryKey<CoinX, CoinY>>();

        assert!(!registry.pools.contains(registry_key), errors::pool_already_deployed());

        let pool_state = PoolState {
            balance_x: coin_x.into_balance(),
            balance_y: coin_y.into_balance(),
            fees: new_fees(),
            locked: false,
            creator_balance_x: balance::zero(),
            creator_balance_y: balance::zero(),
            admin_balance_x: balance::zero(),
            admin_balance_y: balance::zero(),
        };

        let mut pool = InterestPool {
            id: object::new(ctx)
        };

        let pool_address = pool.id.uid_to_address();

        df::add(&mut pool.id, PoolStateKey {}, pool_state);

        registry.pools.add(registry_key, pool_address);

        events::new_pool<CoinX, CoinY>(pool_address, coin_x_value, coin_y_value);

        share_object(pool);
    }

    fun swap_coin_x<CoinX, CoinY>(
        pool: &mut InterestPool,
        mut coin_x: Coin<CoinX>,
        coin_y_min_value: u64,
        ctx: &mut TxContext
    ): Coin<CoinY> {
        let pool_address = object::uid_to_address(&pool.id);
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = coin_x.value();
    
        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_y_min_value, 
            true,
        );

        if (swap_amount.admin_fee_in != 0) {
            pool_state.admin_balance_x.join(coin_x.split(swap_amount.admin_fee_in, ctx).into_balance());
        };

        if (swap_amount.admin_fee_out != 0) {
            pool_state.admin_balance_y.join(pool_state.balance_y.split(swap_amount.admin_fee_out));  
        };

        pool_state.balance_x.join(coin_x.into_balance());

        events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        pool_state.balance_y.split(swap_amount.amount_out).into_coin(ctx) 
    }

    fun swap_coin_y<CoinX, CoinY>(
        pool: &mut InterestPool,
        mut coin_y: Coin<CoinY>,
        coin_x_min_value: u64,
        ctx: &mut TxContext
    ): Coin<CoinX> {
        let pool_address = pool.id.uid_to_address();
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = coin_y.value();
        
        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_x_min_value, 
            false
        );

        if (swap_amount.admin_fee_in != 0) {
            pool_state.admin_balance_y.join(coin_y.split(swap_amount.admin_fee_in, ctx).into_balance());
        };

        if (swap_amount.admin_fee_out != 0) {
            pool_state.admin_balance_x.join(pool_state.balance_x.split(swap_amount.admin_fee_out)); 
        };

        pool_state.balance_y.join(coin_y.into_balance());

        events::swap<CoinY, CoinX, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        pool_state.balance_x.split(swap_amount.amount_out).into_coin(ctx) 
    }  

    fun new_fees(): Fees {
        fees::new(INITIAL_VOLATILE_FEE_PERCENT, INITIAL_VOLATILE_FEE_PERCENT, INITIAL_ADMIN_FEE)
    }

    fun amounts<CoinX, CoinY>(state: &PoolState<CoinX, CoinY>): (u64, u64) {
        ( 
            state.balance_x.value(), 
            state.balance_y.value()
        )
    }

    fun swap_amounts<CoinX, CoinY>(
        pool_state: &PoolState<CoinX, CoinY>,
        coin_in_amount: u64,
        coin_out_min_value: u64,
        is_x: bool
    ): SwapAmount {
        let (balance_x, balance_y) = amounts(pool_state);

        let prev_k = invariant_(balance_x, balance_y);

        let standard_fee_in = pool_state.fees.get_fee_in_amount(coin_in_amount);
        let admin_fee_in =  pool_state.fees.get_admin_amount(standard_fee_in);

        let coin_in_amount = coin_in_amount - standard_fee_in;

        let amount_out =  if (is_x) 
                get_amount_out(coin_in_amount, balance_x, balance_y)
            else 
                get_amount_out(coin_in_amount, balance_y, balance_x);

        let standard_fee_out = pool_state.fees.get_fee_out_amount(amount_out);
        let admin_fee_out = pool_state.fees.get_admin_amount(standard_fee_out);

        let amount_out = amount_out - standard_fee_out;

        assert!(amount_out >= coin_out_min_value, errors::slippage());

        let new_k = if (is_x)
                invariant_(balance_x + coin_in_amount + standard_fee_in - admin_fee_in, balance_y - amount_out - admin_fee_out)
            else
                invariant_(balance_x - amount_out - admin_fee_out, balance_y + coin_in_amount + standard_fee_in - admin_fee_in);

        assert!(new_k >= prev_k, errors::invalid_invariant());

        SwapAmount {
            amount_out,
            standard_fee_in,
            standard_fee_out,
            admin_fee_in,
            admin_fee_out,
        }  
    }

    fun pool_state<CoinX, CoinY>(pool: &InterestPool): &PoolState<CoinX, CoinY> {
        df::borrow(&pool.id, PoolStateKey {})
    }

    fun pool_state_mut<CoinX, CoinY>(pool: &mut InterestPool): &mut PoolState<CoinX, CoinY> {
        df::borrow_mut(&mut pool.id, PoolStateKey {})
    }

    // === Test Functions ===
  
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}