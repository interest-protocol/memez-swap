#[test_only]
module sc_dex::sui_coins_amm_tests {
  use std::string::{utf8, to_ascii};

  use sui::table;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, mint_for_testing, burn_for_testing, TreasuryCap, CoinMetadata};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use sc_dex::admin;
  use sc_dex::math256;
  use sc_dex::eth::ETH;
  use sc_dex::usdc::USDC;
  use sc_dex::curves::{Volatile, Stable};
  use sc_dex::sc_v_eth_usdc::{Self, SC_V_ETH_USDC};
  use sc_dex::sui_coins_amm::{Self, Registry, SuiCoinsPool};
  use sc_dex::test_utils::{people, scenario, deploy_coins, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const USDT_DECIMAL_SCALAR: u64 = 1_000_000_000;

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
    };
    
    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_V_ETH_USDC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_V_ETH_USDC>>(test);
      
      assert_eq(table::is_empty(sui_coins_amm::borrow_pools(&registry)), true);

      let eth_amount = 10 * ETH_DECIMAL_SCALAR;
      let usdc_amount = 25000 * USDC_DECIMAL_SCALAR;
      

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

      let expected_shares = (math256::sqrt_down((eth_amount as u256) * (usdc_amount as u256)) as u64);

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"sc-v-ETH-USDC")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"sc volatile Ether USD Coin Lp Coin"));
      assert_eq(sui_coins_amm::exists_<Volatile, ETH, USDC>(&registry), true);
      assert_eq(burn_for_testing(lp_coin), expected_shares);

      test::return_shared(eth_metadata);
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