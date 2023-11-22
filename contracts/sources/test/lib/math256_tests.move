#[test_only]
module sc_dex::math256_tests {

  use sui::test_utils::assert_eq;
  
  use sc_dex::math256::{diff, div_up, mul_div_down, mul_div_up, sqrt_down, log2_down, min};

  const MAX_U256: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

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
  fun test_diff() {
    assert_eq(diff(0, 0), 0);
    assert_eq(diff(1, 0), 1);
    assert_eq(diff(2, 2), 0);
    assert_eq(diff(3, 2), 1);
    assert_eq(diff(2, 3), 1);
  }

  #[test]
  fun test_div_up() {
    assert_eq(div_up(10, 3), 4);
    assert_eq(div_up(1000, 7), 143);
    assert_eq(div_up(0, 5), 0);
    assert_eq(div_up(8, 8), 1);
    assert_eq(div_up(5, 10), 1);
  }

  #[test]
  fun test_min() {
    assert_eq(min(0,0), 0);
    assert_eq(min(0,1), 0);
    assert_eq(min(3,2), 2);
    assert_eq(min(3,3), 3);
  }

  #[test]
  fun test_sqrt_down() {
    assert_eq(sqrt_down(0), 0);
    assert_eq(sqrt_down(1), 1);
    assert_eq(sqrt_down(2), 1);
    assert_eq(sqrt_down(3), 1);
    assert_eq(sqrt_down(4), 2);
    assert_eq(sqrt_down(144), 12);
    assert_eq(sqrt_down(999999), 999);
    assert_eq(sqrt_down(1000000), 1000);
    assert_eq(sqrt_down(1000001), 1000);
    assert_eq(sqrt_down(1002000), 1000);
    assert_eq(sqrt_down(1002000), 1000);
    assert_eq(sqrt_down(1002001), 1001);
    assert_eq(sqrt_down(1002001), 1001);
    assert_eq(sqrt_down(MAX_U256), 340282366920938463463374607431768211455);
  }

  #[test]
  fun test_log2_down() {
    assert_eq(log2_down(0), 0);
    assert_eq(log2_down(1), 0);
    assert_eq(log2_down(2), 1);
    assert_eq(log2_down(3), 1);
    assert_eq(log2_down(4), 2);
    assert_eq(log2_down(5), 2);
    assert_eq(log2_down(6), 2);
    assert_eq(log2_down(7), 2);
    assert_eq(log2_down(8), 3);
    assert_eq(log2_down(9), 3);
    assert_eq(log2_down(MAX_U256), 255);
  }

  #[test]
  #[expected_failure]
  fun test_div_up_zero_division() {
    div_up(1, 0);
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