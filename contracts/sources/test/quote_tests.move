#[test_only]
module sc_dex::quote_tests {
  use std::option;

  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  
  use sc_dex::fees;
  use sc_dex::quote;
  use sc_dex::volatile;
  use sc_dex::eth::ETH;
  use sc_dex::usdc::USDC;
  use sc_dex::sc_eth_usdc::SC_ETH_USDC;
  use sc_dex::curves::{Volatile, Stable};
  use sc_dex::sui_coins_amm::{Self, Registry, SuiCoinsPool};
  use sc_dex::test_utils::{people, scenario, deploy_coins, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;

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
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_ETH_USDC>(&pool);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::quote_amount_out<ETH, USDC, SC_ETH_USDC>(&pool, amount_in), expected_amount_out);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));
      let pool_fees = sui_coins_amm::fees<ETH, USDC, SC_ETH_USDC>(&pool);

      let amount_in = 14637 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&pool_fees, expected_amount_out); 

      assert_eq(quote::quote_amount_out<USDC, ETH, SC_ETH_USDC>(&pool, amount_in), expected_amount_out);

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