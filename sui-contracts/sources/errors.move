module amm::interest_amm_errors {

    const ENotEnoughFundsToLend: u64 = 0;
    const EFeeIsTooHigh: u64 = 1;
    const ESelectDifferentCoins: u64 = 2;
    const EProvideBothCoins: u64 = 3;
    const ECoinsMustBeOrdered: u64 = 4;
    const EPoolAlreadyDeployed: u64 = 5;
    const ESlippage: u64 = 6;
    const ENoZeroCoin: u64 = 7;
    const EInvalidInvariant: u64 = 8;
    const EPoolIsLocked: u64 = 9;
    const EWrongRepayAmount: u64 = 10;
    const EInsufficientLiquidity: u64 = 11;
    const EWrongPool: u64 = 12;
  
    public fun not_enough_funds_to_lend(): u64 {
        ENotEnoughFundsToLend
    }

    public fun fee_is_too_high(): u64 {
        EFeeIsTooHigh
    }

    public fun select_different_coins(): u64 {
        ESelectDifferentCoins
    }

    public fun provide_both_coins(): u64 {
        EProvideBothCoins
    }

    public fun coins_must_be_ordered(): u64 {
        ECoinsMustBeOrdered
    }

    public fun pool_already_deployed(): u64 {
        EPoolAlreadyDeployed
    }

    public fun slippage(): u64 {
        ESlippage
    }

    public fun no_zero_coin(): u64 {
        ENoZeroCoin
    }

    public fun invalid_invariant(): u64 {
        EInvalidInvariant
    }

    public fun pool_is_locked(): u64 {
        EPoolIsLocked
    }

    public fun wrong_repay_amount(): u64 {
        EWrongRepayAmount
    }

    public fun insufficient_liquidity(): u64 {
        EInsufficientLiquidity
    }

    public fun wrong_pool(): u64 {
        EWrongPool
    }
}