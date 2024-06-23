#[test_only]
module amm::quote_tests {
  
    use sui::{
        test_utils::assert_eq,
        test_scenario::{Self as test, Scenario, next_tx, ctx}
    };
  
    use suitears::math64;

    use amm::{
        eth::ETH,
        usdc::USDC,
        interest_amm_invariant,
        interest_amm_quote as quote,
        interest_amm_utils as utils,
        ipx_eth_usdc::IPX_ETH_USDC,
        interest_amm_fees::{Self as fees, Fees},
        interest_amm::{Self, Registry, InterestPool},
        deploy_utils::{people, scenario, deploy_eth_usdc_pool}
    };

    const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
    const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;

    #[test]
    fun test_volatile_quote_amount_out() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);

            let amount_in = 3 * ETH_DECIMAL_SCALAR;
            let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
            let expected_amount_out = interest_amm_invariant::get_amount_out(amount_in - amount_in_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);
            let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

            assert_eq(quote::amount_out<ETH, USDC, IPX_ETH_USDC>(&request.pool, amount_in), expected_amount_out);

            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);

            let amount_in = 14637 * USDC_DECIMAL_SCALAR;
            let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
            let expected_amount_out = interest_amm_invariant::get_amount_out(amount_in - amount_in_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);
            let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

            assert_eq(quote::amount_out<USDC, ETH, IPX_ETH_USDC>(&request.pool, amount_in), expected_amount_out);

            destroy_request(request);
        };
        test::end(scenario);    
    }

    #[test]
    fun test_volatile_quote_amount_in() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {   
            let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);

            let amount_out = 6 * ETH_DECIMAL_SCALAR;
            let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

            let expected_amount_in = fees::get_fee_in_initial_amount(
                &request.pool_fees, 
                interest_amm_invariant::get_amount_in(amount_out_before_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR)
            );

            assert_eq(quote::amount_in<ETH, USDC, IPX_ETH_USDC>(&request.pool, amount_out), expected_amount_in);

            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);     

            let amount_out = 2999 * USDC_DECIMAL_SCALAR;
            let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

            let expected_amount_in = fees::get_fee_in_initial_amount(
            &request.pool_fees, 
            interest_amm_invariant::get_amount_in(amount_out_before_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR)
            );

            assert_eq(quote::amount_in<USDC, ETH, IPX_ETH_USDC>(&request.pool, amount_out), expected_amount_in);

            destroy_request(request);
        };

        test::end(scenario);
    }   

  #[test]
  fun test_quote_add_liquidity() {
    let mut scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);

      let balance_x = interest_amm::balance_x<ETH, USDC, IPX_ETH_USDC>(&request.pool);
      let balance_y = interest_amm::balance_y<ETH, USDC, IPX_ETH_USDC>(&request.pool);
      let lp_coin_supply = interest_amm::lp_coin_supply<ETH, USDC, IPX_ETH_USDC>(&request.pool);

      let eth_amount = 3 * ETH_DECIMAL_SCALAR;
      let usdc_amount = 15000 * USDC_DECIMAL_SCALAR;
      
      let (shares, optimal_x_amount, optimal_y_amount) = quote::add_liquidity<ETH, USDC, IPX_ETH_USDC>(&request.pool, 3 * ETH_DECIMAL_SCALAR, 15000 * USDC_DECIMAL_SCALAR);

      let (expected_x_amount, expected_y_amount) = utils::get_optimal_add_liquidity(eth_amount, usdc_amount, balance_x, balance_y);

      assert_eq(expected_x_amount, optimal_x_amount);
      assert_eq(expected_y_amount, optimal_y_amount);
      assert_eq(math64::min(
        math64::mul_div_down(optimal_x_amount, lp_coin_supply, balance_x),
        math64::mul_div_down(optimal_y_amount, lp_coin_supply, balance_y),
      ), shares);

      destroy_request(request);  
    };
    test::end(scenario);
  }

    #[test]
    fun test_remove_liquidity() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

        next_tx(scenario_mut, alice);
        {
            let request = request<ETH, USDC, IPX_ETH_USDC>(scenario_mut);

            let balance_x = interest_amm::balance_x<ETH, USDC, IPX_ETH_USDC>(&request.pool);
            let balance_y = interest_amm::balance_y<ETH, USDC, IPX_ETH_USDC>(&request.pool);
            let lp_coin_supply = interest_amm::lp_coin_supply<ETH, USDC, IPX_ETH_USDC>(&request.pool);

            let amount = lp_coin_supply / 3;

            let expected_eth_amount = math64::mul_div_down(amount, balance_x, lp_coin_supply);
            let expected_usdc_amount = math64::mul_div_down(amount, balance_y, lp_coin_supply);

            let (eth_amount, usdc_amount) = quote::remove_liquidity<ETH, USDC, IPX_ETH_USDC>(&request.pool, amount);

            assert_eq(eth_amount, expected_eth_amount);
            assert_eq(usdc_amount, expected_usdc_amount);

            destroy_request(request);  
        };
        test::end(scenario);
    }

    // Set up

    public struct Request {
        registry: Registry,
        pool: InterestPool,
        pool_fees: Fees,
    }

    fun set_up_test(scenario_mut: &mut Scenario) {
        let (alice, _) = people();

        next_tx(scenario_mut, alice);
        {
            interest_amm::init_for_testing(ctx(scenario_mut));
        };
    }

    fun request<CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request {
        let registry = test::take_shared<Registry>(scenario_mut);
        let pool_address = interest_amm::pool_address<CoinX, CoinY>(&registry);
        let pool = test::take_shared_by_id<InterestPool>(
            scenario_mut, object::id_from_address(option::destroy_some(pool_address))
        );
        let pool_fees = interest_amm::fees<CoinX, CoinY, LPCoinType>(&pool);

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