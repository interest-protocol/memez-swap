#[test_only]
module sc_dex::sui_coins_amm_tests {
  use std::option;
  use std::string::{utf8, to_ascii};

  use sui::table;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, mint_for_testing, burn_for_testing, TreasuryCap, CoinMetadata};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use sc_dex::fees;
  use sc_dex::admin;
  use sc_dex::math256;
  use sc_dex::eth::ETH;
  use sc_dex::usdc::USDC;
  use sc_dex::usdt::USDT;
  use sc_dex::curves::{Volatile, Stable};
  use sc_dex::sc_v_eth_usdc::{Self, SC_V_ETH_USDC};
  use sc_dex::sc_s_usdc_usdt::{Self, SC_S_USDC_USDT};
  use sc_dex::sui_coins_amm::{Self, Registry, SuiCoinsPool};
  use sc_dex::test_utils::{people, scenario, deploy_coins, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const MINIMUM_LIQUIDITY: u64 = 100;
  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const USDT_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const INITIAL_STABLE_FEE_PERCENT: u256 = 250_000_000_000_000; // 0.025%
  const INITIAL_VOLATILE_FEE_PERCENT: u256 = 3_000_000_000_000_000; // 0.3%
  const INITIAL_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%

  #[test]
  fun test_new_pool() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);
    set_up_test(test);  
    
    next_tx(test, alice);
    {
      sc_v_eth_usdc::init_for_testing(ctx(test));
      sc_s_usdc_usdt::init_for_testing(ctx(test));
    };


    let eth_amount = 10 * ETH_DECIMAL_SCALAR;
    let usdc_amount = 25000 * USDC_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((eth_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      assert_eq(table::is_empty(sui_coins_amm::borrow_pools(&registry)), true);
      

      let lp_coin = sui_coins_amm::new_pool<ETH, USDC, SC_V_ETH_USDC>(
        &mut registry,
        mint_for_testing(eth_amount, ctx(test)),
        mint_for_testing(usdc_amount, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"sc-v-ETH-USDC")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"sc volatile Ether USD Coin Lp Coin"));
      assert_eq(sui_coins_amm::exists_<Volatile, ETH, USDC>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_id = sui_coins_amm::pool_id<Volatile, ETH, USDC>(&registry);
      let pool = test::take_shared_by_id<SuiCoinsPool>(test, option::destroy_some(pool_id));

      assert_eq(sui_coins_amm::lp_coin_supply<ETH, USDC, SC_V_ETH_USDC>(&pool), expected_shares + MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), eth_amount);
      assert_eq(sui_coins_amm::balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), usdc_amount);
      assert_eq(sui_coins_amm::decimals_x<ETH, USDC, SC_V_ETH_USDC>(&pool), ETH_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::decimals_y<ETH, USDC, SC_V_ETH_USDC>(&pool), USDC_DECIMAL_SCALAR);
      assert_eq(sui_coins_amm::volatile<ETH, USDC, SC_V_ETH_USDC>(&pool), true);
      assert_eq(sui_coins_amm::seed_liquidity<ETH, USDC, SC_V_ETH_USDC>(&pool), MINIMUM_LIQUIDITY);
      assert_eq(sui_coins_amm::locked<ETH, USDC, SC_V_ETH_USDC>(&pool), false);
      assert_eq(sui_coins_amm::admin_balance_x<ETH, USDC, SC_V_ETH_USDC>(&pool), 0);
      assert_eq(sui_coins_amm::admin_balance_y<ETH, USDC, SC_V_ETH_USDC>(&pool), 0);

      let fees = sui_coins_amm::fees<ETH, USDC, SC_V_ETH_USDC>(&pool);

      assert_eq(fees::fee_in_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::fee_out_percent(&fees), INITIAL_VOLATILE_FEE_PERCENT);
      assert_eq(fees::admin_fee_percent(&fees), INITIAL_ADMIN_FEE);

      test::return_shared(registry);
      test::return_shared(pool);
    };

    let usdc_amount = 7777 * USDC_DECIMAL_SCALAR;
    let usdt_amount = 7777 * USDT_DECIMAL_SCALAR;
    let expected_shares = (math256::sqrt_down((usdt_amount as u256) * (usdc_amount as u256)) as u64);

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_S_USDC_USDT>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let usdt_metadata = test::take_shared<CoinMetadata<USDT>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_S_USDC_USDT>>(test);
      
      assert_eq(table::is_empty(sui_coins_amm::borrow_pools(&registry)), false);
      assert_eq(table::length(sui_coins_amm::borrow_pools(&registry)), 1);
      

      let lp_coin = sui_coins_amm::new_pool<USDC, USDT, SC_S_USDC_USDT>(
        &mut registry,
        mint_for_testing(usdc_amount, ctx(test)),
        mint_for_testing(usdt_amount, ctx(test)),
        lp_coin_cap,
        &usdc_metadata,
        &usdt_metadata,
        &mut lp_coin_metadata,
        false,
        ctx(test)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"sc-s-USDC-USDT")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"sc stable USD Coin USD Tether Lp Coin"));
      assert_eq(sui_coins_amm::exists_<Stable, USDC, USDT>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(usdt_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };
    
    test::end(scenario);
  }


  fun set_up_test(test: &mut Scenario) {
    let (alice, _) = people();

    next_tx(test, alice);
    {
      admin::init_for_testing(ctx(test));
      sui_coins_amm::init_for_testing(ctx(test));
    };
  }
}