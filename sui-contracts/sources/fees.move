module amm::interest_amm_fees {

    use suitears::math256::mul_div_up;

    use amm::interest_amm_errors as errors;

    const PRECISION: u256 = 1_000_000_000_000_000_000;
    const MAX_BURN_FEE: u256 = 500_000_000_000_000_000; // 50%
    const MAX_SWAP_FEE: u256 = 15_000_000_000_000_000; // 1.5%
    const MAX_ADMIN_FEE: u256 = 10_000_000_000_000_000; // 1%
    const MAX_LIQUIDITY_FEE: u256 = 50_000_000_000_000_000; // 5%

    public struct Fees has store, copy, drop {
        swap: u256,   
        burn: u256,
        admin: u256,  
        liquidity: u256,
    }

    public fun new(
        swap: u256,
        burn: u256,
        admin: u256,
        liquidity: u256
    ): Fees {
        Fees {
            swap,
            burn,
            admin, 
            liquidity
        }
    }

    public(package) fun swap(self: &Fees): u256 {
        self.swap
    }

    public(package) fun burn(self: &Fees): u256 {
        self.burn
    }

    public(package) fun admin(self: &Fees): u256 {
        self.admin
    }

    public(package) fun liquidity(self: &Fees): u256 {
        self.liquidity
    }

    public(package) fun update_swap(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_SWAP_FEE >= fee, errors::fee_is_too_high());
        self.swap = fee;
    }

    public(package) fun update_burn(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_BURN_FEE >= fee, errors::fee_is_too_high());
       self.burn = fee;
    }

    public(package) fun update_admin(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_ADMIN_FEE >= fee, errors::fee_is_too_high());
       self.admin = fee;
    }

    public(package) fun update_liquidity(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_LIQUIDITY_FEE >= fee, errors::fee_is_too_high());
       self.liquidity = fee;
    }

    public(package) fun get_swap_amount(self: &Fees, amount: u64): u64 {
        get_fee_amount(amount, self.swap)
    }

    public(package) fun get_burn_amount(self: &Fees, amount: u64): u64 {
        get_fee_amount(amount, self.burn)
    }

    public(package) fun get_admin_amount(self: &Fees, amount: u64): u64 {
        get_fee_amount(amount, self.admin)
    }

    public(package) fun get_liquidity_amount(self: &Fees, amount: u64): u64 {
        get_fee_amount(amount, self.liquidity)
    }

    public(package) fun get_swap_amount_initial_amount(self: &Fees, amount: u64): u64 {
        get_initial_amount(amount, self.swap)
    }

    public(package) fun get_burn_amount_initial_amount(self: &Fees, amount: u64): u64 {
        get_initial_amount(amount, self.burn)
    }

    public(package) fun get_admin_amount_initial_amount(self: &Fees, amount: u64): u64 {
        get_initial_amount(amount, self.admin)
    }

    public(package) fun get_liquidity_amount_initial_amount(self: &Fees, amount: u64): u64 {
        get_initial_amount(amount, self.liquidity)
    }

    fun get_fee_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), percent, PRECISION) as u64)
    }

    fun get_initial_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), PRECISION, PRECISION - percent) as u64)
    }
}