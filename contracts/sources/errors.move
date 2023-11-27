module sc_dex::errors {

  public fun not_enough_funds_to_lend(): u64 {
    0
  }

  public fun fee_is_too_high(): u64 {
    1
  }

  public fun select_different_coins(): u64 {
    2
  }

  public fun provide_both_coins(): u64 {
    3
  }

  public fun coins_must_be_ordered(): u64 {
    4
  }

  public fun pool_already_deployed(): u64 {
    5
  }

  public fun supply_must_have_zero_value(): u64 {
    6
  }

  public fun lp_coins_must_have_9_decimals(): u64 {
    7
  }

  public fun slippage(): u64 {
    8
  }

  public fun no_zero_coin(): u64 {
    9
  }

  public fun invalid_invariant(): u64 {
    10
  }

  public fun pool_is_locked(): u64 {
    11
  }

  public fun wrong_repay_amount(): u64 {
    12
  }

  public fun wrong_module_name(): u64 {
    13
  }

  public fun insufficient_liquidity(): u64 {
    14
  }

  public fun wrong_pool(): u64 {
    15
  }
}