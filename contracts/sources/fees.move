module sc_dex::fees {
  use std::option::{Self, Option};

  use sc_dex::math256::mul_div_up;

  use sc_dex::errors;

  const PRECISION: u256 = 1_000_000_000_000_000_000;
  const MAX_FEE_PERCENT: u256 = 20_000_000_000_000_000; // 2%
  const MAX_ADMIN_FEE: u256 = 200_000_000_000_000_000; // 20%

  struct Fees has store, copy, drop {
    fee_in_percent: u256,
    fee_out_percent: u256, 
    admin_fee_percent: u256,     
  }

  public fun new(fee_in_percent: u256, fee_out_percent: u256, admin_fee_percent: u256): Fees {
    Fees {
      fee_in_percent,
      fee_out_percent,
      admin_fee_percent
    }
  }

  public fun fee_in_percent(fees: &Fees): u256 {
    fees.fee_in_percent
  }

  public fun fee_out_percent(fees: &Fees): u256 {
    fees.fee_out_percent
  }

  public fun admin_fee_percent(fees: &Fees): u256 {
    fees.admin_fee_percent
  }

  public fun update_fee_in_percent(fee: &mut Fees, fee_in_percent: Option<u256>) {
    if (option::is_none(&fee_in_percent)) return;
    let fee_in_percent = option::extract(&mut fee_in_percent);
    
    assert!(MAX_FEE_PERCENT >= fee_in_percent, errors::fee_is_too_high());
    fee.fee_in_percent = fee_in_percent;
  }

  public fun update_fee_out_percent(fee: &mut Fees, fee_out_percent: Option<u256>) {
    if (option::is_none(&fee_out_percent)) return;
    let fee_out_percent = option::extract(&mut fee_out_percent);
    
    assert!(MAX_FEE_PERCENT >= fee_out_percent, errors::fee_is_too_high());
    fee.fee_out_percent = fee_out_percent;
  }

  public fun update_admin_fee_percent(fee: &mut Fees, admin_fee_percent: Option<u256>) {
    if (option::is_none(&admin_fee_percent)) return;
    let admin_fee_percent = option::extract(&mut admin_fee_percent);

    assert!(MAX_ADMIN_FEE >= admin_fee_percent, errors::fee_is_too_high());
    fee.admin_fee_percent = admin_fee_percent;
  }

  public fun get_fee_in_amount(fees: &Fees, amount: u64): u64 {
    get_fee_amount(amount, fees.fee_in_percent)
  }

  public fun get_fee_out_amount(fees: &Fees, amount: u64): u64 {
    get_fee_amount(amount, fees.fee_out_percent)
  }

  public fun get_admin_amount(fees: &Fees, amount: u64): u64 {
    get_fee_amount(amount, fees.admin_fee_percent)
  }

  public fun get_fee_in_initial_amount(fees: &Fees, amount: u64): u64 {
    get_initial_amount(amount, fees.fee_in_percent)
  }

  public fun get_fee_out_initial_amount(fees: &Fees, amount: u64): u64 {
    get_initial_amount(amount, fees.fee_out_percent)
  }

  fun get_fee_amount(x: u64, percent: u256): u64 {
    (mul_div_up((x as u256), percent, PRECISION) as u64)
  }

  fun get_initial_amount(x: u64, percent: u256): u64 {
    (mul_div_up((x as u256), PRECISION, PRECISION - percent) as u64)
  }
}