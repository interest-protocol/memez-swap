#[test_only]
module amm::quote_tests {

    use sui::{
        test_utils::assert_eq,
        test_scenario::{Self as test, Scenario, next_tx, ctx}
    };

    use amm::{
        btc::BTC,
        eth::ETH,
        usdc::USDC,
        memez_amm_admin::Admin,
        memez_amm_quote as quote,
        memez_amm_fees::{Self as fees, Fees},
        memez_amm::{Self, Registry, MemezPool},
        deploy_utils::{people, scenario, deploy_btc_eth_pool,  deploy_eth_usdc_pool}
    };

    use memez_v2_invariant::memez_v2_invariant;

    const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
    const BTC_DECIMAL_SCALAR: u64 = 1_000_000_000;
    const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;

    #[test]
    fun test_quote_amount_out_no_burn_fee() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC>(scenario_mut);

            let amount_in = 3 * ETH_DECIMAL_SCALAR;
            let burn_fee = fees::get_burn_amount(&request.pool_fees, amount_in);
            let swap_fee = fees::get_swap_amount(&request.pool_fees, amount_in - burn_fee);

            let expected_amount_out = memez_v2_invariant::get_amount_out(amount_in - burn_fee - swap_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

            assert_eq(quote::amount_out<ETH, USDC>(&request.pool, amount_in), expected_amount_out);

            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC>(scenario_mut);

            let amount_in = 14637 * USDC_DECIMAL_SCALAR;

            let burn_fee = fees::get_burn_amount(&request.pool_fees, amount_in);
            let swap_fee = fees::get_swap_amount(&request.pool_fees, amount_in - burn_fee);

            let expected_amount_out = memez_v2_invariant::get_amount_out(amount_in - burn_fee - swap_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);

            assert_eq(quote::amount_out<USDC, ETH>(&request.pool, amount_in), expected_amount_out);

            destroy_request(request);
        };
        test::end(scenario);    
    }

    #[test]
    fun test_quote_amount_in_no_burn_fee() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {   
            let request = request<ETH, USDC>(scenario_mut);

            let amount_out = 6 * ETH_DECIMAL_SCALAR;
            let amount_in = memez_v2_invariant::get_amount_in(amount_out, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

            let amount_in_before_swap_fee = fees::get_swap_amount_initial_amount(&request.pool_fees, amount_in);
            let amount_in_before_burn_fee = fees::get_burn_amount_initial_amount(&request.pool_fees, amount_in_before_swap_fee);

            assert_eq(quote::amount_in<ETH, USDC>(&request.pool, amount_out), amount_in_before_burn_fee);

            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC>(scenario_mut);     

            let amount_out = 2999 * USDC_DECIMAL_SCALAR;
            let amount_in = memez_v2_invariant::get_amount_in(amount_out, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);

            let amount_in_before_swap_fee = fees::get_swap_amount_initial_amount(&request.pool_fees, amount_in);
            let amount_in_before_burn_fee = fees::get_burn_amount_initial_amount(&request.pool_fees, amount_in_before_swap_fee);

            assert_eq(amount_in_before_burn_fee, amount_in_before_swap_fee);
            assert_eq(quote::amount_in<USDC, ETH>(&request.pool, amount_out), amount_in_before_burn_fee);

            destroy_request(request);
        };

        test::end(scenario);
    }   

    #[test]
    fun test_quote_amount_out_burn_fee() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_btc_eth_pool(scenario_mut, 3 * BTC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {
            let mut request = request<BTC, ETH>(scenario_mut);

            let admin = test::take_from_sender<Admin>(scenario_mut);

            memez_amm::add_burn_coin<BTC, ETH, BTC>(&mut request.pool, &admin);

            let amount_in = 3 * ETH_DECIMAL_SCALAR;
            let swap_fee = fees::get_swap_amount(&request.pool_fees, amount_in);

            let expected_amount_out = memez_v2_invariant::get_amount_out(amount_in - swap_fee, 15 * ETH_DECIMAL_SCALAR, 3 * BTC_DECIMAL_SCALAR);

            assert_eq(quote::amount_out<ETH, BTC>(&request.pool, amount_in), expected_amount_out);

            test::return_to_sender(scenario_mut, admin);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<BTC, ETH>(scenario_mut);

            let amount_in = 1 * BTC_DECIMAL_SCALAR / 10;

            let burn_fee = fees::get_burn_amount(&request.pool_fees, amount_in);
            let swap_fee = fees::get_swap_amount(&request.pool_fees, amount_in - burn_fee);

            let expected_amount_out = memez_v2_invariant::get_amount_out(amount_in - burn_fee - swap_fee, 3 * BTC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);

            assert_eq(quote::amount_out<BTC, ETH>(&request.pool, amount_in), expected_amount_out);

            destroy_request(request);
        };
        test::end(scenario);    
    }

    #[test]
    fun test_quote_amount_in_burn_fee() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_btc_eth_pool(scenario_mut, 3 * BTC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {
            let mut request = request<BTC, ETH>(scenario_mut);

            let admin = test::take_from_sender<Admin>(scenario_mut);

            memez_amm::add_burn_coin<BTC, ETH, BTC>(&mut request.pool, &admin);

            let amount_out = 3 * ETH_DECIMAL_SCALAR;

            let amount_in = memez_v2_invariant::get_amount_in(amount_out, 3 * BTC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);
            let amount_in_before_swap_fee = fees::get_swap_amount_initial_amount(&request.pool_fees, amount_in);
            let amount_in_before_burn_fee = fees::get_burn_amount_initial_amount(&request.pool_fees, amount_in_before_swap_fee);

            assert_eq(quote::amount_in<BTC, ETH>(&request.pool, amount_out), amount_in_before_burn_fee);

            test::return_to_sender(scenario_mut, admin);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<BTC, ETH>(scenario_mut);

            let amount_out = 1 * BTC_DECIMAL_SCALAR / 10;

            let amount_in = memez_v2_invariant::get_amount_in(amount_out, 15 * ETH_DECIMAL_SCALAR, 3 * BTC_DECIMAL_SCALAR);
            let amount_in_before_swap_fee = fees::get_swap_amount_initial_amount(&request.pool_fees, amount_in);

            assert_eq(quote::amount_in<ETH, BTC>(&request.pool, amount_out), amount_in_before_swap_fee);

            destroy_request(request);
        };
        test::end(scenario);    
    }

    // Set up

    public struct Request {
        registry: Registry,
        pool: MemezPool,
        pool_fees: Fees,
    }

    fun set_up_test(scenario_mut: &mut Scenario) {
        let (alice, _) = people();

        next_tx(scenario_mut, alice);
        {
            memez_amm::init_for_testing(ctx(scenario_mut));
        };
    }

    fun request<CoinX, CoinY>(scenario_mut: &Scenario): Request {
        let registry = test::take_shared<Registry>(scenario_mut);
        let pool_address = memez_amm::pool_address<CoinX, CoinY>(&registry);
        let pool = test::take_shared_by_id<MemezPool>(
            scenario_mut, object::id_from_address(option::destroy_some(pool_address))
        );
        let pool_fees = memez_amm::fees<CoinX, CoinY>(&pool);

        Request {
            registry,
            pool,
            pool_fees,
        }
    }

    fun destroy_request(request: Request) {
        let Request { registry, pool, pool_fees: _ } = request;

        test::return_shared(registry);
        test::return_shared(pool); 
    }
}