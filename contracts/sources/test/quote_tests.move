#[test_only]
module sc_dex::quote_tests {
  use std::option;

  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  
  use sc_dex::fees;
  use sc_dex::quote;
  use sc_dex::utils;
  use sc_dex::stable;
  use sc_dex::math64;
  use sc_dex::volatile;
  use sc_dex::eth::ETH;
  use sc_dex::usdc::USDC;
  use sc_dex::usdt::USDT;
  use sc_dex::sc_v_eth_usdc::SC_V_ETH_USDC;
  use sc_dex::sc_s_usdc_usdt::SC_S_USDC_USDT;
  use sc_dex::curves::{Volatile, Stable};
  use sc_dex::sui_coins_amm::{Self, Registry, SuiCoinsPool};
  use sc_dex::test_utils::{people, scenario, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const USDT_DECIMAL_SCALAR: u64 = 1_000_000_000;

  #[test]
  fun test_volatile_quote_amount_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_eth_usdc_pool(test, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<ETH, USDC, SC_V_ETH_USDC>(&pool, amount_in), expected_amount_out);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount_in = 14637 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDC, ETH, SC_V_ETH_USDC>(&pool, amount_in), expected_amount_out);

      test::return_shared(registry);
      test::return_shared(pool);
    };
    test::end(scenario);    
  }

  #[test]
  fun test_stable_quote_amount_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_usdc_usdt_pool(test, 25000 * USDC_DECIMAL_SCALAR, 25000 * USDT_DECIMAL_SCALAR);    

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_in = 599 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee, 
        25000 * USDC_DECIMAL_SCALAR, 
        25000 * USDT_DECIMAL_SCALAR,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        true
      );
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDC, USDT, SC_S_USDC_USDT>(&pool, amount_in), expected_amount_out);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_in = 763 * USDT_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee, 
        25000 * USDC_DECIMAL_SCALAR, 
        25000 * USDT_DECIMAL_SCALAR,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        false
      );
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDT, USDC, SC_S_USDC_USDT>(&pool, amount_in), expected_amount_out);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    test::end(scenario);
  }

  #[test]
  fun test_volatile_quote_amount_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_eth_usdc_pool(test, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);     

      let amount_out = 6 * ETH_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &pool_fees, 
        volatile::get_amount_in(amount_out_before_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR)
      );

      assert_eq(quote::amount_in<ETH, USDC, SC_V_ETH_USDC>(&pool, amount_out), expected_amount_in);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);     

      let amount_out = 2999 * USDC_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &pool_fees, 
        volatile::get_amount_in(amount_out_before_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR)
      );

      assert_eq(quote::amount_in<USDC, ETH, SC_V_ETH_USDC>(&pool, amount_out), expected_amount_in);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    test::end(scenario);
  }

  #[test]
  fun test_stable_quote_amount_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_usdc_usdt_pool(test, 25000 * USDC_DECIMAL_SCALAR, 25000 * USDT_DECIMAL_SCALAR); 
    
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_out = 2999 * USDC_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &pool_fees, 
        stable::get_amount_in(
          amount_out_before_fee,
          25000 * USDC_DECIMAL_SCALAR, 
          25000 * USDT_DECIMAL_SCALAR,
          USDC_DECIMAL_SCALAR,
          USDT_DECIMAL_SCALAR,
          true          
        )
      );

      assert_eq(quote::amount_in<USDC, USDT, SC_S_USDC_USDT>(&pool, amount_out), expected_amount_in);

      test::return_shared(registry);
      test::return_shared(pool);   
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Stable, USDC, USDT>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<USDC, USDT, SC_S_USDC_USDT>(&pool);

      let amount_out = 2999 * USDT_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &pool_fees, 
        stable::get_amount_in(
          amount_out_before_fee,
          25000 * USDC_DECIMAL_SCALAR, 
          25000 * USDT_DECIMAL_SCALAR,
          USDC_DECIMAL_SCALAR,
          USDT_DECIMAL_SCALAR,
          false          
        )
      );

      assert_eq(quote::amount_in<USDT, USDC, SC_S_USDC_USDT>(&pool, amount_out), expected_amount_in);

      test::return_shared(registry);
      test::return_shared(pool);   
    };

    test::end(scenario);
  }

  #[test]
  fun test_quote_add_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_eth_usdc_pool(test, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let balance_x = sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let balance_y = sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let eth_amount = 3 * ETH_DECIMAL_SCALAR;
      let usdc_amount = 15000 * USDC_DECIMAL_SCALAR;
      
      let (shares, optimal_x_amount, optimal_y_amount) = quote::add_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, 3 * ETH_DECIMAL_SCALAR, 15000 * USDC_DECIMAL_SCALAR);

      let (expected_x_amount, expected_y_amount) = utils::get_optimal_add_liquidity(eth_amount, usdc_amount, balance_x, balance_y);

      assert_eq(expected_x_amount, optimal_x_amount);
      assert_eq(expected_y_amount, optimal_y_amount);
      assert_eq(math64::min(
        math64::mul_div_down(optimal_x_amount, lp_coin_supply, balance_x),
        math64::mul_div_down(optimal_y_amount, lp_coin_supply, balance_y),
      ), shares);

      test::return_shared(registry);
      test::return_shared(pool); 
    };
    test::end(scenario);
  }

  #[test]
  fun test_remove_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    set_up_test(test);
    deploy_eth_usdc_pool(test, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      let balance_x = sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let balance_y = sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool);
      let lp_coin_supply = sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool);

      let amount = lp_coin_supply / 3;

      let expected_eth_amount = math64::mul_div_down(amount, balance_x, lp_coin_supply);
      let expected_usdc_amount = math64::mul_div_down(amount, balance_y, lp_coin_supply);

      let (eth_amount, usdc_amount) = quote::remove_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool, amount);

      assert_eq(eth_amount, expected_eth_amount);
      assert_eq(usdc_amount, expected_usdc_amount);

      test::return_shared(registry);
      test::return_shared(pool);     
    };
    test::end(scenario);
  }

  fun set_up_test(test: &mut Scenario) {
    let (alice, _) = people();

    next_tx(test, alice);
    {
      sui_coins_amm::init_for_testing(ctx(test));
    };
  }
}