module amm::memez_amm_fees {

    use suitears::math256::{mul_div_up, clamp};

    use amm::memez_amm_errors as errors;

    const PRECISION: u256 = 1_000_000_000_000_000_000;
    const MAX_BURN_FEE: u256 = 500_000_000_000_000_000; // 50%
    const MAX_SWAP_FEE: u256 = 25_000_000_000_000_000; // 2.5%
    const MAX_ADMIN_FEE: u256 = 300_000_000_000_000_000; // 30%
    const MAX_LIQUIDITY_FEE: u256 = 500_000_000_000_000_000; // 50%
    const MAX_SHILLER_FEE: u256 = 300_000_000_000_000_000; // 30%
    const MAX_MULTIPLIER: u256 = 5;

    public struct Fees has store, copy, drop {
        max_swap_multiplier: u256,
        swap: u256,   
        // Applied before the swap fee
        burn: u256,
        // They are a % of the swap fee
        admin: u256,  
        liquidity: u256,
        shiller: u256
    }

    public fun new(
        max_swap_multiplier: u256,
        swap: u256,
        burn: u256,
        admin: u256,
        liquidity: u256,
        shiller: u256
    ): Fees {
        Fees {
            max_swap_multiplier,
            swap,
            burn,
            admin, 
            liquidity,
            shiller
        }
    }

    public(package) fun swap(self: &Fees): u256 {
        self.swap
    }

    public(package) fun max_swap_multiplier(self: &Fees): u256 {
        self.max_swap_multiplier
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

    public(package) fun shiller(self: &Fees): u256 {
        self.shiller
    }    

    public(package) fun update_swap(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_SWAP_FEE >= fee, errors::fee_is_too_high());
        self.swap = fee;
    }

    public(package) fun update_max_swap_multiplier(self: &mut Fees, mut multiplier: Option<u256>) {
        if (option::is_none(&multiplier)) return;
        let multiplier = option::extract(&mut multiplier);
    
        assert!(MAX_MULTIPLIER >= multiplier, errors::fee_is_too_high());
        self.max_swap_multiplier = multiplier;
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

    public(package) fun update_shiller(self: &mut Fees, mut fee: Option<u256>) {
        if (option::is_none(&fee)) return;
        let fee = option::extract(&mut fee);
    
        assert!(MAX_SHILLER_FEE >= fee, errors::fee_is_too_high());
       self.shiller = fee;
    }

    public(package) fun get_swap_amount(self: &Fees, amount: u64, volume_multiplier: u256): u64 {
        let swap = mul_div_up(volume_multiplier, self.swap, PRECISION);
        get_fee_amount(amount, clamp(swap, self.swap, self.swap * self.max_swap_multiplier))
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

    public(package) fun get_shiller_amount(self: &Fees, amount: u64): u64 {
        get_fee_amount(amount, self.shiller)
    }

    public(package) fun get_swap_amount_initial_amount(self: &Fees, amount: u64, volume_multiplier: u256): u64 {
        let swap = mul_div_up(volume_multiplier, self.swap, PRECISION);
        get_initial_amount(amount, clamp(swap, self.swap, self.swap * self.max_swap_multiplier))
    }

    public(package) fun get_burn_amount_initial_amount(self: &Fees, amount: u64): u64 {
        get_initial_amount(amount, self.burn)
    }

    fun get_fee_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), percent, PRECISION) as u64)
    }

    fun get_initial_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), PRECISION, PRECISION - percent) as u64)
    }
}