#[test_only]
module sc_dex::utils_tests {
  use std::string::{utf8, to_ascii};

  use sui::sui::SUI;
  use sui::coin::CoinMetadata;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx};

  use sc_dex::btc::BTC;
  use sc_dex::eth::ETH;
  use sc_dex::sc_v_btc_eth::{Self, SC_V_BTC_ETH};
  use sc_dex::sc_btce_eth::{Self, SC_BTCE_ETH};
  use sc_dex::sc_btc_eth_wrong_decimals::{Self, SC_BTC_ETH_WRONG_DECIMALS};
  use sc_dex::test_utils::{scenario, people, deploy_coins};
  use sc_dex::utils::{
    is_coin_x, 
    quote_liquidity,
    get_lp_coin_name,
    are_coins_ordered, 
    get_lp_coin_symbol,
    assert_lp_coin_integrity,
    get_optimal_add_liquidity, 
  };

  struct ABC {}

  struct CAB {}

  #[test]
  fun test_are_coins_ordered() {
    assert_eq(are_coins_ordered<SUI, ABC>(), true);
    assert_eq(are_coins_ordered<ABC, SUI>(), false);
    assert_eq(are_coins_ordered<ABC, CAB>(), true);
    assert_eq(are_coins_ordered<CAB, ABC>(), false);
  }

  #[test]
  fun test_is_coin_x() {
    assert_eq(is_coin_x<SUI, ABC>(), true);
    assert_eq(is_coin_x<ABC, SUI>(), false);
    assert_eq(is_coin_x<ABC, CAB>(), true);
    assert_eq(is_coin_x<CAB, ABC>(), false);
    // does not throw
    assert_eq(is_coin_x<ETH, ETH>(), false);
  }

  #[test]
  fun test_get_optimal_add_liquidity() {
    let (x, y) = get_optimal_add_liquidity(5, 10, 0, 0);
    assert_eq(x, 5);
    assert_eq(y, 10);

    let (x, y) = get_optimal_add_liquidity(8, 4, 20, 30);
    assert_eq(x, 3);
    assert_eq(y, 4);

    let (x, y) = get_optimal_add_liquidity(15, 25, 50, 100);
    assert_eq(x, 13);
    assert_eq(y, 25);

    let (x, y) = get_optimal_add_liquidity(12, 18, 30, 20);
    assert_eq(x, 12);
    assert_eq(y, 8);

    let (x, y) = get_optimal_add_liquidity(9876543210,1234567890,987654,123456);
    assert_eq(x, 9876543210);
    assert_eq(y, 1234560402);

    let (x, y) = get_optimal_add_liquidity(999999999, 888888888, 777777777, 666666666);
    assert_eq(x, 999999999);
    assert_eq(y, 857142857);

    let (x, y) = get_optimal_add_liquidity(987654321, 9876543210, 123456, 987654);
    assert_eq(x, 987654321);
    assert_eq(y, 7901282569);
  }

  #[test]
  fun test_quote_liquidity() {
    assert_eq(quote_liquidity(10, 2, 5), 25);
    assert_eq(quote_liquidity(1000000, 100, 50000), 500000000);
    assert_eq(quote_liquidity(7, 7, 7), 7);
    assert_eq(quote_liquidity(0, 2, 100), 0);
    assert_eq(quote_liquidity(7, 3, 2), 5); // ~ 4.6
  }

  #[test]
  fun test_get_lp_coin_name() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice); 
    {
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);

      assert_eq(get_lp_coin_name<BTC, ETH>(
        &btc_metadata,
        &eth_metadata,
        true
      ),
      utf8(b"sc volatile Bitcoin Ether Lp Coin")
      );

      assert_eq(get_lp_coin_name<BTC, ETH>(
        &btc_metadata,
        &eth_metadata,
        false
      ),
      utf8(b"sc stable Bitcoin Ether Lp Coin")
      );

      test::return_shared(btc_metadata);
      test::return_shared(eth_metadata);
    };

    test::end(scenario);
  }

  #[test]
  fun test_get_lp_coin_symbol() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice); 
    {
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);

      assert_eq(get_lp_coin_symbol<BTC, ETH>(
        &btc_metadata,
        &eth_metadata,
        true
      ),
      to_ascii(utf8(b"sc-v-BTC-ETH"))
      );

      assert_eq(get_lp_coin_symbol<BTC, ETH>(
        &btc_metadata,
        &eth_metadata,
        false
      ),
      to_ascii(utf8(b"sc-s-BTC-ETH"))
      );

      test::return_shared(btc_metadata);
      test::return_shared(eth_metadata);
    };

    test::end(scenario);
  }

  #[test]
  fun test_assert_lp_coin_integrity() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      sc_v_btc_eth::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<SC_V_BTC_ETH>>(test);

      assert_lp_coin_integrity<BTC, ETH, SC_V_BTC_ETH>(&metadata, true);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = 7)]
  fun test_assert_lp_coin_integrity_wrong_decimal() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      sc_btc_eth_wrong_decimals::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<SC_BTC_ETH_WRONG_DECIMALS>>(test);

      assert_lp_coin_integrity<BTC, ETH, SC_BTC_ETH_WRONG_DECIMALS>(&metadata, true);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = 4)]
  fun test_assert_lp_coin_integrity_wrong_coin_order() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      sc_btc_eth_wrong_decimals::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<BTC>>(test);

      assert_lp_coin_integrity<ETH, BTC, BTC>(&metadata, true);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = 13)]
  fun test_assert_lp_coin_integrity_wrong_lp_module_name() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      sc_btce_eth::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<SC_BTCE_ETH>>(test);

      assert_lp_coin_integrity<BTC, ETH, SC_BTCE_ETH>(&metadata, true);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure]
  fun test_are_coins_ordered_same_coin() {
    are_coins_ordered<SUI, SUI>();
  }
}

#[test_only]
module sc_dex::sc_btc_eth_wrong_decimals {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct SC_BTC_ETH_WRONG_DECIMALS has drop {}


  fun init(witness: SC_BTC_ETH_WRONG_DECIMALS, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<SC_BTC_ETH_WRONG_DECIMALS>(
            witness, 
            8, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      transfer::public_share_object(metadata);
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(SC_BTC_ETH_WRONG_DECIMALS {}, ctx);
  }  
}
