module amm::memez_amm {
    // === Imports ===
  
    use std::type_name::{Self, TypeName};

    use sui::{
        coin::Coin,
        clock::Clock,
        dynamic_field as df,
        table::{Self, Table},
        transfer::share_object,
        balance::{Self, Balance},
    };

    use suitears::math256::mul_div_up; 

    use amm::{
        memez_amm_admin::Admin,
        memez_amm_utils as utils,
        memez_amm_errors as errors,
        memez_amm_events as events,
        memez_amm_shill::{Shillers, Shill},
        memez_amm_fees::{Self as fees, Fees},    
        memez_amm_volume::{Self as volume, Volume},
        memez_amm_invariant::{invariant_, get_amount_out},
    };

    // === Constants ===
    const PRECISION: u256 = 1_000_000_000_000_000_000;
    const INITIAL_SWAP_FEE: u256 = 1_000_000_000_000_000; // 1%
    const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%
    const INITIAL_SHILLER_FEE: u256 = 100_000_000_000_000_000; // 10%
    const INITIAL_LIQUIDITY_FEE: u256 = 500_000_000_000_000_000; // 50%
    const FLASH_LOAN_FEE_PERCENT: u256 = 5_000_000_000_000_000; //0.5% 
    const INITIAL_SWAP_MULTIPLIER: u256 = 3;
    const BURN_WALLET: address = @0x0;

    // === Structs ===

    public struct Registry has key {
        id: UID,
        pools: Table<TypeName, address>,
    }
  
    public struct MemezPool has key {
        id: UID 
    }

    public struct RegistryKey<phantom CoinX, phantom CoinY> has drop {}

    public struct PoolStateKey has drop, copy, store {}

    public struct PoolState<phantom CoinX, phantom CoinY> has store {
        fees: Fees,
        locked: bool,
        balance_x: Balance<CoinX>,
        balance_y: Balance<CoinY>,
        burn_coin: Option<TypeName>,
        admin_balance_x: Balance<CoinX>,
        admin_balance_y: Balance<CoinY>,
        deployer_balance_x: Balance<CoinX>,
        deployer_balance_y: Balance<CoinY>,
        volume: Volume
    } 

    public struct Deployer has key, store {
        id: UID,
        pool: address
    }

    public struct SwapAmount has store, drop, copy {
        amount_out: u64,
        burn_fee: u64,
        admin_fee: u64,
        swap_fee: u64,
        liquidity_fee: u64,
        creator_fee: u64,
        shiller_fee: u64
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
    ): Deployer {
        new_pool_internal<CoinX, CoinY>(registry, coin_x, coin_y, ctx)
    }

    public fun swap<CoinIn, CoinOut>(
        pool: &mut MemezPool, 
        clock: &Clock,
        coin_in: Coin<CoinIn>,
        coin_min_value: u64,
        ctx: &mut TxContext    
    ): Coin<CoinOut> {
        assert!(coin_in.value() != 0, errors::no_zero_coin());

        if (utils::is_coin_x<CoinIn, CoinOut>()) 
            swap_coin_x<CoinIn, CoinOut>(pool, clock, coin_in, coin_min_value, ctx)
        else 
            swap_coin_y<CoinOut, CoinIn>(pool, clock, coin_in, coin_min_value, ctx)
    }

    public fun shilled_swap<CoinIn, CoinOut>(
        pool: &mut MemezPool, 
        clock: &Clock,
        shillers: &Shillers,
        shill: Shill,
        coin_in: Coin<CoinIn>,
        coin_min_value: u64,
        ctx: &mut TxContext   
    ): Coin<CoinOut> {
        assert!(coin_in.value() != 0, errors::no_zero_coin());
        assert!(type_name::get<CoinIn>() == shill.coin(), errors::invalid_shilled_coin());

        if (utils::is_coin_x<CoinIn, CoinOut>()) 
            shilled_swap_coin_x<CoinIn, CoinOut>(pool, clock, shillers, shill, coin_in, coin_min_value, ctx)
        else 
            shilled_swap_coin_y<CoinOut, CoinIn>(pool, clock, shillers, shill, coin_in, coin_min_value, ctx)
    }

    // === Flash Loans ===

    public fun flash_loan<CoinX, CoinY>(
        pool: &mut MemezPool,
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
        pool: &mut MemezPool,
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

    public fun exists_<CoinX, CoinY>(registry: &Registry): bool {
        registry.pools.contains(type_name::get<RegistryKey<CoinX, CoinY>>())   
    }

    public fun burn_coin<CoinX, CoinY>(pool: &MemezPool): Option<TypeName> {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.burn_coin
    }

    public fun balance_x<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.balance_x.value()
    }

    public fun balance_y<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.balance_y.value()
    }

    public fun fees<CoinX, CoinY>(pool: &MemezPool): Fees {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.fees
    }

    public fun locked<CoinX, CoinY>(pool: &MemezPool): bool {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.locked
    }

    public fun volume<CoinX, CoinY>(pool: &MemezPool): &Volume {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        &pool_state.volume
    }

    public fun admin_balance_x<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.admin_balance_x.value()
    }

    public fun admin_balance_y<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.admin_balance_y.value()
    }

    public fun deployer_balance_x<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.deployer_balance_x.value()
    }

    public fun deployer_balance_y<CoinX, CoinY>(pool: &MemezPool): u64 {
        let pool_state = pool_state<CoinX, CoinY>(pool);
        pool_state.deployer_balance_y.value()
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

    // === Deployer Functions ===

    public fun take_deployer_fees<CoinX, CoinY>(
        deployer: &Deployer,
        pool: &mut MemezPool,
        ctx: &mut TxContext
    ): (Coin<CoinX>, Coin<CoinY>) {
        let pool_address = pool.id.uid_to_address();

        assert!(deployer.pool == pool_address, errors::wrong_pool());

        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        let amount_x = pool_state.deployer_balance_x.value();
        let amount_y = pool_state.deployer_balance_y.value();

        events::take_deployer_fees(pool_address, amount_x, amount_y);

        (
            pool_state.deployer_balance_x.withdraw_all().into_coin(ctx),
            pool_state.deployer_balance_y.withdraw_all().into_coin(ctx),    
        )
    }

    // === Admin Functions ===

    public fun add_burn_coin<CoinX, CoinY, BurnCoin>(
        pool: &mut MemezPool,
        _: &Admin,
    ) {
        let pool_address = pool.id.uid_to_address();

        assert!(
            type_name::get<CoinX>() == type_name::get<BurnCoin>() ||
            type_name::get<CoinY>() == type_name::get<BurnCoin>(),
            errors::burn_coin()
        );

        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        pool_state.burn_coin.fill(type_name::get<BurnCoin>());

        events::add_burn_coin(pool_address, type_name::get<BurnCoin>());
    }

    public fun remove_burn_coin<CoinX, CoinY>(
        pool: &mut MemezPool,
        _: &Admin,
    ) {
        let pool_address = pool.id.uid_to_address();

        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        pool_state.burn_coin = option::none();
        events::remove_burn_coin(pool_address);
    }

    public fun update_fees<CoinX, CoinY>(
        pool: &mut MemezPool,
        _: &Admin,
        swap: Option<u256>,
        burn: Option<u256>, 
        admin: Option<u256>,
        liquidity: Option<u256>,  
    ) {
        let pool_address = pool.id.uid_to_address();
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        pool_state.fees.update_swap(swap);
        pool_state.fees.update_burn(burn);  
        pool_state.fees.update_admin(admin);
        pool_state.fees.update_liquidity(liquidity);

        events::update_fees(pool_address, pool_state.fees);
    }

    public fun take_admin_fees<CoinX, CoinY>(
        pool: &mut MemezPool,
        _: &Admin,
        ctx: &mut TxContext
    ): (Coin<CoinX>, Coin<CoinY>) {
        let pool_address = pool.id.uid_to_address();
        let pool_state = pool_state_mut<CoinX, CoinY>(pool);

        let amount_x = pool_state.admin_balance_x.value();
        let amount_y = pool_state.admin_balance_y.value();

        events::take_admin_fees(pool_address, amount_x, amount_y);

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
    ): Deployer {
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
            burn_coin: option::none(),
            deployer_balance_x: balance::zero(),
            deployer_balance_y: balance::zero(),
            admin_balance_x: balance::zero(),
            admin_balance_y: balance::zero(),
            volume: volume::new()
        };

        let mut pool = MemezPool {
            id: object::new(ctx)
        };

        let pool_address = pool.id.uid_to_address();

        df::add(&mut pool.id, PoolStateKey {}, pool_state);

        registry.pools.add(registry_key, pool_address);

        let deployer = Deployer {
            id: object::new(ctx),
            pool: pool_address
        };

        events::new_pool<CoinX, CoinY>(pool_address, deployer.id.uid_to_address(), coin_x_value, coin_y_value);

        share_object(pool);

        deployer
    }

    fun swap_coin_x<CoinX, CoinY>(
        pool: &mut MemezPool,
        clock: &Clock,
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
            clock,
            coin_in_amount, 
            coin_y_min_value, 
            true,
            false
        );

        if (swap_amount.burn_fee != 0) {
            let burn_coin = coin_x.split(swap_amount.burn_fee, ctx);
            transfer::public_transfer(burn_coin, BURN_WALLET);
        };

        if (swap_amount.admin_fee != 0) {
            pool_state.admin_balance_x.join(coin_x.split(swap_amount.admin_fee, ctx).into_balance());  
        };

        if (swap_amount.creator_fee != 0) {
            pool_state.deployer_balance_x.join(coin_x.split(swap_amount.creator_fee, ctx).into_balance());  
        };

        pool_state.balance_x.join(coin_x.into_balance());

        events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        pool_state.balance_y.split(swap_amount.amount_out).into_coin(ctx) 
    }

    fun swap_coin_y<CoinX, CoinY>(
        pool: &mut MemezPool,
        clock: &Clock,
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
            clock,
            coin_in_amount, 
            coin_x_min_value, 
            false,
            false
        );

        if (swap_amount.burn_fee != 0) {
            let burn_coin = coin_y.split(swap_amount.burn_fee, ctx);
            transfer::public_transfer(burn_coin, BURN_WALLET);
        };

        if (swap_amount.admin_fee != 0) {
            pool_state.admin_balance_y.join(coin_y.split(swap_amount.admin_fee, ctx).into_balance());  
        };

        if (swap_amount.creator_fee != 0) {
            pool_state.deployer_balance_y.join(coin_y.split(swap_amount.creator_fee, ctx).into_balance());  
        };

        pool_state.balance_y.join(coin_y.into_balance());

        events::swap<CoinY, CoinX, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        pool_state.balance_x.split(swap_amount.amount_out).into_coin(ctx) 
    }  

    fun shilled_swap_coin_x<CoinX, CoinY>(
        pool: &mut MemezPool, 
        clock: &Clock,
        shillers: &Shillers,
        shill: Shill,
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
            clock,
            coin_in_amount, 
            coin_y_min_value, 
            true,
            true
        );

        if (swap_amount.burn_fee != 0) {
            let burn_coin = coin_x.split(swap_amount.burn_fee, ctx);
            transfer::public_transfer(burn_coin, BURN_WALLET);
        };

        if (swap_amount.shiller_fee != 0) {
            transfer::public_transfer(coin_x.split(swap_amount.shiller_fee, ctx), shill.shiller());
        };

        shill.destroy(shillers);

        if (swap_amount.admin_fee != 0) {
            pool_state.admin_balance_x.join(coin_x.split(swap_amount.admin_fee, ctx).into_balance());  
        };

        if (swap_amount.creator_fee != 0) {
            pool_state.deployer_balance_x.join(coin_x.split(swap_amount.creator_fee, ctx).into_balance());  
        };

        pool_state.balance_x.join(coin_x.into_balance());

        events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        pool_state.balance_y.split(swap_amount.amount_out).into_coin(ctx) 
    }

    fun shilled_swap_coin_y<CoinX, CoinY>(
        pool: &mut MemezPool, 
        clock: &Clock,
        shillers: &Shillers,
        shill: Shill,
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
            clock,
            coin_in_amount, 
            coin_x_min_value, 
            false,
            true
        );

        if (swap_amount.burn_fee != 0) {
            let burn_coin = coin_y.split(swap_amount.burn_fee, ctx);
            transfer::public_transfer(burn_coin, BURN_WALLET);
        };

        if (swap_amount.shiller_fee != 0) {
            transfer::public_transfer(coin_y.split(swap_amount.shiller_fee, ctx), shill.shiller());
        };

        shill.destroy(shillers);

        if (swap_amount.admin_fee != 0) {
            pool_state.admin_balance_y.join(coin_y.split(swap_amount.admin_fee, ctx).into_balance());  
        };

        if (swap_amount.creator_fee != 0) {
            pool_state.deployer_balance_y.join(coin_y.split(swap_amount.creator_fee, ctx).into_balance());  
        };

        pool_state.balance_y.join(coin_y.into_balance());

        events::swap<CoinY, CoinX, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        pool_state.balance_x.split(swap_amount.amount_out).into_coin(ctx) 
    }  

    fun new_fees(): Fees {
        fees::new(
            INITIAL_SWAP_MULTIPLIER,
            INITIAL_SWAP_FEE, 
            0,
            INITIAL_ADMIN_FEE, 
            INITIAL_LIQUIDITY_FEE,
            INITIAL_SHILLER_FEE
        )
    }

    fun amounts<CoinX, CoinY>(state: &PoolState<CoinX, CoinY>): (u64, u64) {
        ( 
            state.balance_x.value(), 
            state.balance_y.value()
        )
    }

    fun swap_amounts<CoinX, CoinY>(
        pool_state: &mut PoolState<CoinX, CoinY>,
        clock: &Clock,
        coin_in_amount: u64,
        coin_out_min_value: u64,
        is_x: bool,
        is_shilled: bool
    ): SwapAmount {
        let (balance_x, balance_y) = amounts(pool_state);

        let prev_k = invariant_(balance_x, balance_y);

        let is_burn_coin = if (pool_state.burn_coin.is_some())
            {
                let coin_in_type = if (is_x) type_name::get<CoinX>() else type_name::get<CoinY>();
                coin_in_type == *pool_state.burn_coin.borrow()
            }
        else 
            false;
        
        let burn_fee = if (is_burn_coin) pool_state.fees.get_burn_amount(coin_in_amount) else 0;
        let swap_fee = pool_state.dynamic_swap_fee_impl(clock, coin_in_amount - burn_fee, is_x);
        
        let shiller_fee = if (is_shilled) pool_state.fees.get_liquidity_amount(swap_fee) else 0;
        let liquidity_fee = pool_state.fees.get_liquidity_amount(swap_fee);
        let admin_fee = pool_state.fees.get_admin_amount(swap_fee);
        let creator_fee = swap_fee - admin_fee - liquidity_fee - shiller_fee;

        let coin_in_amount = coin_in_amount - burn_fee - swap_fee;

        let amount_out =  if (is_x) 
                get_amount_out(coin_in_amount, balance_x, balance_y)
            else 
                get_amount_out(coin_in_amount, balance_y, balance_x);

        assert!(amount_out >= coin_out_min_value, errors::slippage());

        let new_k = if (is_x)
                invariant_(balance_x + coin_in_amount + liquidity_fee, balance_y - amount_out)
            else
                invariant_(balance_x - amount_out, balance_y + coin_in_amount + liquidity_fee);

        assert!(new_k >= prev_k, errors::invalid_invariant());

        SwapAmount {
            amount_out,
            swap_fee,
            burn_fee,
            admin_fee,
            liquidity_fee,
            creator_fee,
            shiller_fee
        }  
    }

    fun dynamic_swap_fee_impl<CoinX, CoinY>(
        pool_state: &mut PoolState<CoinX, CoinY>,
        clock: &Clock,
        coin_in_amount: u64,
        is_x: bool
    ): u64 {
        let multiplier = if (is_x) 
            pool_state.volume.add_coin_x(clock, coin_in_amount)
        else 
            pool_state.volume.add_coin_y(clock, coin_in_amount);

        pool_state.fees.get_swap_amount(coin_in_amount, multiplier)
    }

    fun pool_state<CoinX, CoinY>(pool: &MemezPool): &PoolState<CoinX, CoinY> {
        df::borrow(&pool.id, PoolStateKey {})
    }

    fun pool_state_mut<CoinX, CoinY>(pool: &mut MemezPool): &mut PoolState<CoinX, CoinY> {
        df::borrow_mut(&mut pool.id, PoolStateKey {})
    }

    // === Test Functions ===
  
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}