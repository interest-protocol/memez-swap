#[test_only]
module sc_dex::fees_tests {
  use std::option;

  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx};

  use sc_dex::fees;
  
  use sc_dex::test_utils::{people, scenario};

  const INITIAL_FEE_PERCENT: u256 = 250000000000000; // 0.025%
  const MAX_FEE_PERCENT: u256 = 20000000000000000; // 2%
  const MAX_ADMIN_FEE: u256 = 200000000000000000; // 20%

  #[test]
  fun sets_initial_state_correctly() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    

    next_tx(test, alice);
    {
      
      let fees = fees::new(INITIAL_FEE_PERCENT, INITIAL_FEE_PERCENT + 1, INITIAL_FEE_PERCENT + 2);

      let fee_in = fees::fee_in_percent(&fees);
      let fee_out = fees::fee_out_percent(&fees);
      let fee_admin = fees::admin_fee_percent(&fees);

      assert_eq(fee_in, INITIAL_FEE_PERCENT);
      assert_eq(fee_out, INITIAL_FEE_PERCENT + 1);
      assert_eq(fee_admin, INITIAL_FEE_PERCENT + 2);

    };
    test::end(scenario);      
  }

  #[test]
  fun updates_fees_correctly() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    

    next_tx(test, alice);
    {
      let fees = fees::new(INITIAL_FEE_PERCENT, INITIAL_FEE_PERCENT + 1, INITIAL_FEE_PERCENT + 2);

      fees::update_fee_in_percent(&mut fees, option::some(MAX_FEE_PERCENT));
      fees::update_fee_out_percent(&mut fees, option::some(MAX_FEE_PERCENT));
      fees::update_admin_fee_percent(&mut fees, option::some(1));

      let fee_in = fees::fee_in_percent(&fees);
      let fee_out = fees::fee_out_percent(&fees);
      let fee_admin = fees::admin_fee_percent(&fees);

      assert_eq(fee_in, MAX_FEE_PERCENT);
      assert_eq(fee_out, MAX_FEE_PERCENT);
      assert_eq(fee_admin, 1);

      fees::update_fee_in_percent(&mut fees, option::none());
      fees::update_fee_out_percent(&mut fees, option::none());
      fees::update_admin_fee_percent(&mut fees, option::none());

      let fee_in = fees::fee_in_percent(&fees);
      let fee_out = fees::fee_out_percent(&fees);
      let fee_admin = fees::admin_fee_percent(&fees);

      assert_eq(fee_in, MAX_FEE_PERCENT);
      assert_eq(fee_out, MAX_FEE_PERCENT);
      assert_eq(fee_admin, 1);

      fees::update_fee_in_percent(&mut fees, option::some(0));
      fees::update_fee_out_percent(&mut fees, option::some(0));
      fees::update_admin_fee_percent(&mut fees, option::some(0));

      let fee_in = fees::fee_in_percent(&fees);
      let fee_out = fees::fee_out_percent(&fees);
      let fee_admin = fees::admin_fee_percent(&fees);

      assert_eq(fee_in, 0);
      assert_eq(fee_out, 0);
      assert_eq(fee_admin, 0);
    };
    test::end(scenario);
  }

  #[test]
  fun calculates_fees_properly() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
    

    next_tx(test, alice);
    {
      let fees = fees::new(0, 0, 0);

      fees::update_fee_in_percent(&mut fees, option::some(MAX_FEE_PERCENT)); // 2%
      fees::update_fee_out_percent(&mut fees, option::some(MAX_FEE_PERCENT / 2)); // 1%
      fees::update_admin_fee_percent(&mut fees, option::some(MAX_FEE_PERCENT * 2)); // 4%

      let amount = 100;

      assert_eq(fees::get_fee_in_amount(&fees, amount), 2);
      assert_eq(fees::get_fee_out_amount(&fees, amount), 1);
      assert_eq(fees::get_admin_amount(&fees, amount), 4);

      assert_eq(fees::get_fee_in_initial_amount(&fees, amount), 103); // rounds up
      assert_eq(fees::get_fee_out_initial_amount(&fees, amount), 102); // rounds up
    };
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 1)]  
  fun aborts_max_fee_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      let fees = fees::new(0, 0, 0);

      fees::update_fee_in_percent(&mut fees, option::some(MAX_FEE_PERCENT + 1));
    };
    test::end(scenario);
  }  

  #[test]
  #[expected_failure(abort_code = 1)]  
  fun aborts_max_fee_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    next_tx(test, alice);
    {
      let fees = fees::new(0, 0, 0);

      fees::update_fee_out_percent(&mut fees, option::some(MAX_FEE_PERCENT + 1));
    };
    test::end(scenario);
  }   

  #[test]
  #[expected_failure(abort_code = 1)]  
  fun aborts_max_admin_fee() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;
   
    next_tx(test, alice);
    {
      let fees = fees::new(0, 0, 0);
      fees::update_admin_fee_percent(&mut fees, option::some(MAX_ADMIN_FEE + 1));
    };
    test::end(scenario);
  }  
}