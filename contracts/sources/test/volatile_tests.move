#[test_only]
module sc_dex::volatile_tests {
  use sui::test_utils::assert_eq;

  use sc_dex::volatile;

  #[test]
  fun test_invariant() {
    assert_eq(volatile::invariant_(0, 1), 0);
    assert_eq(volatile::invariant_(1, 0), 0);
    assert_eq(volatile::invariant_(1234, 1234), 1234 * 1234);
    assert_eq(volatile::invariant_(1000000000000000003, 3), 3000000000000000009);
    assert_eq(volatile::invariant_(3000000000000000009, 1), 3000000000000000009);
  }

  #[test]
  fun test_get_amount_in() {
    assert_eq(volatile::get_amount_in(5, 100, 200), 3);
    assert_eq(volatile::get_amount_in(1000, 1000000, 2000000), 501);
    assert_eq(volatile::get_amount_in(1, 18446744073709551615, 18446744073709551615), 2);
  }

  #[test]
  fun test_get_amount_out() {
    assert_eq(volatile::get_amount_out(5, 100, 200), 9);
    assert_eq(volatile::get_amount_out(1000, 1000000, 2000000), 1998);
    assert_eq(volatile::get_amount_out(25, 25, 200), 100);
    assert_eq(volatile::get_amount_out(1, 18446744073709551615, 18446744073709551615), 0);
  }

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun test_get_amount_in_zero_coin_amount() {
    assert_eq(volatile::get_amount_in(0, 75, 150), 0);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun test_get_amount_in_zero_balance_in() {
    assert_eq(volatile::get_amount_in(10, 0, 50), 3);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun test_get_amount_in_zero_balance_out() {
    assert_eq(volatile::get_amount_in(10, 50, 0), 3);
  }

  #[test]
  #[expected_failure]  
  fun test_get_amount_in_coin_out_equal_to_balance_out() {
    assert_eq(volatile::get_amount_in(25, 200, 25), 3);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun test_get_amount_out_zero_balance_in() {
    assert_eq(volatile::get_amount_out(10, 0, 150), 3);
  }

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun test_get_amount_out_zero_coin_amount() {
    assert_eq(volatile::get_amount_out(0, 75, 150), 0);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun test_get_amount_out_zero_balance_out() {
    assert_eq(volatile::get_amount_out(10, 150, 0), 3);
  }
}