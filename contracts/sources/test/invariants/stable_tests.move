#[test_only]
module sc_dex::stable_tests {
  use sui::test_utils::assert_eq;

  use sc_dex::stable;

  const PRECISION: u256 = 1_000_000_000_000_000_000;


  #[test]
  fun invariant_() {

    let x = fdiv(300000, 1000000);
    let y = fdiv(500000, 1000000);
    assert_eq(stable::invariant_(300000, 500000, 1000000, 1000000), fmul(fmul(fmul(x, x), x), y) + fmul(fmul(fmul(y, y), y), x));


    let x = fdiv(500000899318256, 1000000);
    let y = fdiv(25000567572582123, 1000000000000);
    assert_eq(stable::invariant_(500000899318256, 25000567572582123, 1000000, 1000000000000), fmul(fmul(x, y), fmul(x, x) + fmul(y, y)));
  }

  #[test]
  fun calculate_amounts() {
    assert_eq(
      stable::get_amount_out(2513058000,  25582858050757, 2558285805075712, 1000000, 100000000, true),
      251305799999
    );

    assert_eq(
      stable::get_amount_out(2513058000,  25582858050757, 2558285805075712, 1000000, 100000000, false),
      25130579
    );

    assert_eq(
      stable::get_amount_in(251305800000,  2558285805075701, 25582858050757, 100000000, 1000000, true),
      2513058001
    );

    assert_eq(
      stable::get_amount_in(2513058000,  2558285805075701, 25582858050757, 100000000, 1000000, false),
      251305800001
    );
  }

  #[test]
  fun f() {
    let x0 = 10000518365287 * 1_000_000_000;
    let y = 2520572000001255 * 1_000_000_000;

    let r = stable::f(x0, y);
    assert_eq(r, 160149899619106589403934712464197979435638);

    let r = stable::f(0, 0);
    assert_eq(r, 0);
  }

  #[test]
  fun d() {
    let x0 = 10000518365287 * 1_000_000_000;
    let y = 2520572000001255 * 1_000_000_000;

    let z = stable::d(x0, y);
    assert_eq(z, 190609376335646708870399576464086697);

    let x0 = 5000000000 * 1_000_000_000;
    let y = 10000000000000000 * 1_000_000_000;

    let z = stable::d(x0, y);

    assert_eq(z,  1500000000000125000000000000000000);

    let x0 = 1 * 1_000_000_000_000_000_000;
    let y = 2 * 1_000_000_000_000_000_000;

    let z = stable::d(x0, y);
    assert_eq(z, 13000000000000000000);
  }

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun get_amount_in_zero_coin() {
    stable::get_amount_in( 0,  2558285805075701, 25582858050757, 100000000, 1000000, true);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun get_amount_in_zero_balance_x() {
    stable::get_amount_in( 1,  0, 25582858050757, 100000000, 1000000, true);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun get_amount_in_zero_balance_y() {
    stable::get_amount_in( 1,  1, 0, 100000000, 1000000, true);
  }

  #[test]
  #[expected_failure(abort_code = 9)]  
  fun get_amount_out_zero_coin() {
    stable::get_amount_out( 0,  2558285805075701, 25582858050757, 100000000, 1000000, true);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun get_amount_out_zero_balance_x() {
    stable::get_amount_in( 1,  0, 25582858050757, 100000000, 1000000, true);
  }

  #[test]
  #[expected_failure(abort_code = 14)]  
  fun get_amount_out_zero_balance_y() {
    stable::get_amount_in( 1,  1, 0, 100000000, 1000000, true);
  }

  fun fmul(x: u256, y: u256): u256 {
    x * y / PRECISION
  }

  fun fdiv(x: u256, y: u256): u256 {
    x * PRECISION / y
  }
}