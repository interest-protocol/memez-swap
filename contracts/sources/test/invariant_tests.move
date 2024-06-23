#[test_only]
module amm::invariant_tests {
  use sui::test_utils::assert_eq;

  use amm::interest_amm_invariant;

  #[test]
  fun test_invariant() {
    assert_eq(interest_amm_invariant::invariant_(0, 1), 0);
    assert_eq(interest_amm_invariant::invariant_(1, 0), 0);
    assert_eq(interest_amm_invariant::invariant_(1234, 1234), 1234 * 1234);
    assert_eq(interest_amm_invariant::invariant_(1000000000000000003, 3), 3000000000000000009);
    assert_eq(interest_amm_invariant::invariant_(3000000000000000009, 1), 3000000000000000009);
  }

  #[test]
  fun test_get_amount_in() {
    assert_eq(interest_amm_invariant::get_amount_in(5, 100, 200), 3);
    assert_eq(interest_amm_invariant::get_amount_in(1000, 1000000, 2000000), 501);
    assert_eq(interest_amm_invariant::get_amount_in(1, 18446744073709551615, 18446744073709551615), 2);
  }

  #[test]
  fun test_get_amount_out() {
    assert_eq(interest_amm_invariant::get_amount_out(5, 100, 200), 9);
    assert_eq(interest_amm_invariant::get_amount_out(1000, 1000000, 2000000), 1998);
    assert_eq(interest_amm_invariant::get_amount_out(25, 25, 200), 100);
    assert_eq(interest_amm_invariant::get_amount_out(1, 18446744073709551615, 18446744073709551615), 0);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::ENoZeroCoin, location = amm::interest_amm_invariant)]  
  fun test_get_amount_in_zero_coin_amount() {
    assert_eq(interest_amm_invariant::get_amount_in(0, 75, 150), 0);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::EInsufficientLiquidity, location = amm::interest_amm_invariant)]  
  fun test_get_amount_in_zero_balance_in() {
    assert_eq(interest_amm_invariant::get_amount_in(10, 0, 50), 3);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::EInsufficientLiquidity, location = amm::interest_amm_invariant)]  
  fun test_get_amount_in_zero_balance_out() {
    assert_eq(interest_amm_invariant::get_amount_in(10, 50, 0), 3);
  }

  #[test]
  #[expected_failure]  
  fun test_get_amount_in_coin_out_equal_to_balance_out() {
    assert_eq(interest_amm_invariant::get_amount_in(25, 200, 25), 3);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::EInsufficientLiquidity, location = amm::interest_amm_invariant)]  
  fun test_get_amount_out_zero_balance_in() {
    assert_eq(interest_amm_invariant::get_amount_out(10, 0, 150), 3);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::ENoZeroCoin, location = amm::interest_amm_invariant)]  
  fun test_get_amount_out_zero_coin_amount() {
    assert_eq(interest_amm_invariant::get_amount_out(0, 75, 150), 0);
  }

  #[test]
  #[expected_failure(abort_code = amm::interest_amm_errors::EInsufficientLiquidity, location = amm::interest_amm_invariant)]  
  fun test_get_amount_out_zero_balance_out() {
    assert_eq(interest_amm_invariant::get_amount_out(10, 150, 0), 3);
  }
}