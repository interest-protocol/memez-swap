module amm::errors {

    const ENotEnoughFundsToLend: u64 = 0;
    const EFeeIsTooHigh: u64 = 1;
    const ESelectDifferentCoins: u64 = 2;
    const EProvideBothCoins: u64 = 3;
    const ECoinsMustBeOrdered: u64 = 4;
    const EPoolAlreadyDeployed: u64 = 5;
    const ESupplyMustHaveZeroValue: u64 = 6;
    const ELpCoinsMustHave9Decimals: u64 = 7;
    const ESlippage: u64 = 8;
    const ENoZeroCoin: u64 = 9;
    const EInvalidInvariant: u64 = 10;
    const EPoolIsLocked: u64 = 11;
    const EWrongRepayAmount: u64 = 12;
    const EWrongModuleName: u64 = 13;
    const EInsufficientLiquidity: u64 = 14;
    const EWrongPool: u64 = 15;
    const EDepositAmountIsTooLow: u64 = 16;
  
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

    public fun supply_must_have_zero_value(): u64 {
        ESupplyMustHaveZeroValue
    }

    public fun lp_coins_must_have_9_decimals(): u64 {
        ELpCoinsMustHave9Decimals
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

    public fun wrong_module_name(): u64 {
        EWrongModuleName
    }

    public fun insufficient_liquidity(): u64 {
        EInsufficientLiquidity
    }

    public fun wrong_pool(): u64 {
        EWrongPool
    }

    public fun deposit_amount_is_too_low(): u64 {
        EDepositAmountIsTooLow
    }
}