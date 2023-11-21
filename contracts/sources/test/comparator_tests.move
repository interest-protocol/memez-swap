#[test_only]
module sc_dex::comparator_tests {
  use std::vector;
  use std::string;

  use sui::test_utils::assert_eq;

  use sc_dex::comparator::{is_equal, compare, is_greater_than, is_smaller_than};

  struct Complex has drop {
    value0: vector<u128>,
    value1: u8,
    value2: u64,
  }
 
  #[test]
  public fun test_strings() {
    let value0 = string::utf8(b"alpha");
    let value1 = string::utf8(b"beta");
    let value2 = string::utf8(b"betaa");

    assert_eq(is_equal(&compare(&value0, &value0)), true);
    assert_eq(is_equal(&compare(&value1, &value1)), true);
    assert_eq(is_equal(&compare(&value2, &value2)), true);

    assert_eq(is_greater_than(&compare(&value0, &value1)), true);
    assert_eq(is_smaller_than(&compare(&value1, &value0)), true);

    assert_eq(is_smaller_than(&compare(&value0, &value2)), true);
    assert_eq(is_greater_than(&compare(&value2, &value0)), true);

    assert_eq(is_smaller_than(&compare(&value1, &value2)), true);
    assert_eq(is_greater_than(&compare(&value2, &value1)), true);
  }

  #[test]
  #[expected_failure]
  public fun test_integer_error() {
    // 1(0x1) will be larger than 256(0x100) after BCS serialization.
    let value0: u128 = 1;
    let value1: u128 = 256;

    assert_eq(is_equal(&compare(&value0, &value0)), true);
    assert_eq(is_equal(&compare(&value1, &value1)), true);

    assert!(is_smaller_than(&compare(&value0, &value1)), 2);
    assert!(is_greater_than(&compare(&value1, &value0)), 3);
  }

  #[test]
  public fun test_u128() {
    let value0: u128 = 5;
    let value1: u128 = 152;
    let value2: u128 = 511; // 0x1ff

    assert_eq(is_equal(&compare(&value0, &value0)), true);
    assert_eq(is_equal(&compare(&value1, &value1)), true);
    assert_eq(is_equal(&compare(&value2, &value2)), true);

    assert_eq(is_smaller_than(&compare(&value0, &value1)), true);
    assert_eq(is_greater_than(&compare(&value1, &value0)), true);

    assert_eq(is_smaller_than(&compare(&value0, &value2)), true);
    assert_eq(is_greater_than(&compare(&value2, &value0)), true);

    assert_eq(is_smaller_than(&compare(&value1, &value2)), true);
    assert_eq(is_greater_than(&compare(&value2, &value1)), true);
  }


  #[test]
  public fun test_complex() {
    let value0_0 = vector::empty();
    vector::push_back(&mut value0_0, 10);
    vector::push_back(&mut value0_0, 9);
    vector::push_back(&mut value0_0, 5);

    let value0_1 = vector::empty();
    vector::push_back(&mut value0_1, 10);
    vector::push_back(&mut value0_1, 9);
    vector::push_back(&mut value0_1, 5);
    vector::push_back(&mut value0_1, 1);

    let base = Complex {
      value0: value0_0,
      value1: 13,
      value2: 41,
    };

    let other_0 = Complex {
      value0: value0_1,
      value1: 13,
      value2: 41,
    };

    let other_1 = Complex {
      value0: copy value0_0,
      value1: 14,
      value2: 41,
    };

    let other_2 = Complex {
      value0: value0_0,
      value1: 13,
      value2: 42,
    };

    assert_eq(is_equal(&compare(&base, &base)), true);
    assert_eq(is_smaller_than(&compare(&base, &other_0)), true);
    assert_eq(is_greater_than(&compare(&other_0, &base)), true);
    assert_eq(is_smaller_than(&compare(&base, &other_1)), true);
    assert_eq(is_greater_than(&compare(&other_1, &base)), true);
    assert_eq(is_smaller_than(&compare(&base, &other_2)), true);
    assert_eq(is_greater_than(&compare(&other_2, &base)), true);
  }  
}