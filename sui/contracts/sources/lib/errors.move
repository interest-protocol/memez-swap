module amm::memez_amm_errors {

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
    const EInvalidBurnCoin: u64 = 13;
    const EYouAreNotAShiller: u64 = 14;
    const ECannotSkillYourself: u64 = 15;
    const EInvalidShilledCoin: u64 = 16;
  
    public(package) fun not_enough_funds_to_lend(): u64 {
        ENotEnoughFundsToLend
    }

    public(package) fun fee_is_too_high(): u64 {
        EFeeIsTooHigh
    }

    public(package) fun select_different_coins(): u64 {
        ESelectDifferentCoins
    }

    public(package) fun provide_both_coins(): u64 {
        EProvideBothCoins
    }

    public(package) fun coins_must_be_ordered(): u64 {
        ECoinsMustBeOrdered
    }

    public(package) fun pool_already_deployed(): u64 {
        EPoolAlreadyDeployed
    }

    public(package) fun slippage(): u64 {
        ESlippage
    }

    public(package) fun no_zero_coin(): u64 {
        ENoZeroCoin
    }

    public(package) fun invalid_invariant(): u64 {
        EInvalidInvariant
    }

    public(package) fun pool_is_locked(): u64 {
        EPoolIsLocked
    }

    public(package) fun wrong_repay_amount(): u64 {
        EWrongRepayAmount
    }

    public(package) fun insufficient_liquidity(): u64 {
        EInsufficientLiquidity
    }

    public(package) fun wrong_pool(): u64 {
        EWrongPool
    }

    public(package) fun burn_coin(): u64 {
        EInvalidBurnCoin
    }

    public(package) fun you_are_not_a_shiller(): u64 {
        EYouAreNotAShiller
    }

    public(package) fun cannot_shill_yourself(): u64 {
        ECannotSkillYourself
    }

    public(package) fun invalid_shilled_coin(): u64 {
        EInvalidShilledCoin
    }
}