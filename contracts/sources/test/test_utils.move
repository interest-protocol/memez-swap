#[test_only]
module sc_dex::test_utils {

  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use sc_dex::btc;
  use sc_dex::eth;
  use sc_dex::usdc;

  public fun deploy_coins(test: &mut Scenario) {
    let (alice, _) = people();

    next_tx(test, alice);
    {
      btc::init_for_testing(ctx(test));
      eth::init_for_testing(ctx(test));
      usdc::init_for_testing(ctx(test));
    };
  }

  public fun scenario(): Scenario { test::begin(@0x1) }

  public fun people():(address, address) { (@0xBEEF, @0x1337)}
}