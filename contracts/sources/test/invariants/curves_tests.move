#[test_only]
module amm::curves_tests {
  use sui::test_utils::assert_eq;

  use amm::curves::{Self, Volatile, Stable};

  public struct Any {}

  #[test]
  fun test_is_volatile() {
    assert_eq(curves::is_volatile<Volatile>(), true);
    assert_eq(curves::is_volatile<Stable>(), false);
    assert_eq(curves::is_volatile<Any>(), false);
  }
}