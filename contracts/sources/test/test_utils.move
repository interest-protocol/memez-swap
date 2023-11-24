#[test_only]
module sc_dex::test_utils {

  use sui::transfer;
  use sui::coin::{mint_for_testing, TreasuryCap, CoinMetadata};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use sc_dex::btc;
  use sc_dex::usdt::{Self, USDT};
  use sc_dex::eth::{Self, ETH};
  use sc_dex::usdc::{Self, USDC};
  use sc_dex::sc_v_eth_usdc::{Self, SC_V_ETH_USDC};
  use sc_dex::sui_coins_amm::{Self, Registry};
  use sc_dex::sc_s_usdc_usdt::{Self, SC_S_USDC_USDT};

  public fun deploy_coins(test: &mut Scenario) {
    let (alice, _) = people();

    next_tx(test, alice);
    {
      btc::init_for_testing(ctx(test));
      eth::init_for_testing(ctx(test));
      usdc::init_for_testing(ctx(test));
      usdt::init_for_testing(ctx(test));
    };
  }

  public fun deploy_eth_usdc_pool(test: &mut Scenario, eth_amount: u64, usdc_amount: u64) {
    let (alice, _) = people();

    deploy_coins(test);

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
      
      let lp_coin = sui_coins_amm::new_pool(
        &mut registry,
        mint_for_testing<ETH>(eth_amount, ctx(test)),
        mint_for_testing<USDC>(usdc_amount, ctx(test)),
        lp_coin_cap,
        &eth_metadata,
        &usdc_metadata,
        &mut lp_coin_metadata,
        true,
        ctx(test)
      );

      transfer::public_transfer(lp_coin, alice);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };
  }

  public fun deploy_usdc_usdt_pool(test: &mut Scenario, usdc_amount: u64, usdt_amount: u64,) {
    let (alice, _) = people();

    deploy_coins(test);

    next_tx(test, alice);
    {
      sc_s_usdc_usdt::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<SC_S_USDC_USDT>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let usdt_metadata = test::take_shared<CoinMetadata<USDT>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<SC_S_USDC_USDT>>(test);
      
      let lp_coin = sui_coins_amm::new_pool(
        &mut registry,
        mint_for_testing<USDC>(usdc_amount, ctx(test)),
        mint_for_testing<USDT>(usdt_amount, ctx(test)),
        lp_coin_cap,
        &usdc_metadata,
        &usdt_metadata,
        &mut lp_coin_metadata,
        false,
        ctx(test)
      );

      transfer::public_transfer(lp_coin, alice);

      test::return_shared(usdc_metadata);
      test::return_shared(usdt_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };
  }  

  public fun scenario(): Scenario { test::begin(@0x1) }

  public fun people():(address, address) { (@0xBEEF, @0x1337)}
}