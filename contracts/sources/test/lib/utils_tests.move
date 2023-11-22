#[test_only]
module sc_dex::utils_tests {

  use sui::sui::SUI;
  use sui::test_utils::assert_eq;

  use sc_dex::utils::{are_coins_ordered, is_coin_x, get_optimal_add_liquidity, quote_liquidity};

  struct BTC {}

  struct ETH {}

  #[test]
  fun test_are_coins_ordered() {
    assert_eq(are_coins_ordered<SUI, BTC>(), true);
    assert_eq(are_coins_ordered<BTC, SUI>(), false);
    assert_eq(are_coins_ordered<BTC, ETH>(), true);
    assert_eq(are_coins_ordered<ETH, BTC>(), false);
  }

  #[test]
  fun test_is_coin_x() {
    assert_eq(is_coin_x<SUI, BTC>(), true);
    assert_eq(is_coin_x<BTC, SUI>(), false);
    assert_eq(is_coin_x<BTC, ETH>(), true);
    assert_eq(is_coin_x<ETH, BTC>(), false);
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
  #[expected_failure]
  fun test_are_coins_ordered_same_coin() {
    are_coins_ordered<SUI, SUI>();
  }
}
