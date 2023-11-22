#[test_only]
module sc_dex::math64_tests {

  use sui::test_utils::assert_eq;
  
  use sc_dex::math64::{min, mul_div_down, mul_div_up};

  #[test]
  fun test_mul_div_down() {
    assert_eq(mul_div_down(10, 5, 2), 25);
    assert_eq(mul_div_down(1000000, 50000, 100), 500000000);
    assert_eq(mul_div_down(7, 7, 7), 7);
    assert_eq(mul_div_down(0, 100, 2), 0);
    assert_eq(mul_div_down(7, 2, 3), 4); // ~ 4.6
  }

  #[test]
  fun test_mul_div_up() {
    assert_eq(mul_div_up(10, 5, 2), 25);
    assert_eq(mul_div_up(1000000, 50000, 100), 500000000);
    assert_eq(mul_div_up(7, 7, 7), 7);
    assert_eq(mul_div_up(0, 100, 2), 0);
    assert_eq(mul_div_up(7, 2, 3), 5); // ~ 4.6
  }

  #[test]
  fun test_min() {
    assert_eq(min(0,0), 0);
    assert_eq(min(0,1), 0);
    assert_eq(min(3,2), 2);
    assert_eq(min(3,3), 3);
  }

  #[test]
  #[expected_failure]
  fun test_mul_div_down_zero_denominator() {
    mul_div_down(15, 3, 0);
  }

  #[test]
  #[expected_failure]
  fun test_mul_div_up_zero_denominator() {
    mul_div_up(15, 3, 0);
  }
}