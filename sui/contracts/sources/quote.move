module amm::memez_amm_quote {

    use std::type_name::{Self, TypeName};

    use amm::{
        memez_amm_fees::Fees,
        memez_amm::MemezPool,
        memez_amm_utils::is_coin_x
    };

    use memez_v2_invariant::memez_v2_invariant;

    public fun amount_out<CoinIn, CoinOut>(pool: &MemezPool, amount_in: u64): u64 { 
        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, multiplier_x, _, fees, burn_coin) = get_pool_data<CoinIn, CoinOut>(pool);

            memez_v2_invariant::get_amount_out(
                sub_fees_out<CoinIn>(fees, amount_in, burn_coin, multiplier_x), 
                balance_x, 
                balance_y
            )
        } else {
            let (balance_x, balance_y, _, multiplier_y, fees, burn_coin) = get_pool_data<CoinOut, CoinIn>(pool);

            memez_v2_invariant::get_amount_out(
                sub_fees_out<CoinIn>(fees, amount_in, burn_coin, multiplier_y), 
                balance_y, 
                balance_x
            )
        }
  }

    public fun amount_in<CoinIn, CoinOut>(pool: &MemezPool, amount_out: u64): u64 {

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, multiplier_x, _, fees, burn_coin) = get_pool_data<CoinIn, CoinOut>(pool);
            
            sub_fees_in<CoinIn>(
                fees, 
                memez_v2_invariant::get_amount_in(amount_out, balance_x, balance_y), 
                burn_coin,
                multiplier_x
            )
        } else {
            let (balance_x, balance_y, _, multiplier_y, fees, burn_coin) = get_pool_data<CoinOut, CoinIn>(pool);

            sub_fees_in<CoinIn>(
                fees, 
                memez_v2_invariant::get_amount_in(amount_out, balance_y, balance_x), 
                burn_coin,
                multiplier_y
            )
        }
    }

    fun sub_fees_in<CoinIn>(fees: Fees, amount: u64, burn_coin: Option<TypeName>, multiplier: u256): u64 {
        if (is_burn_coin<CoinIn>(burn_coin)) 
            fees.get_burn_amount_initial_amount(
                fees.get_swap_amount_initial_amount(amount, multiplier)
            )
        else
            fees.get_swap_amount_initial_amount(amount, multiplier)
    }

    fun sub_fees_out<CoinIn>(fees: Fees, amount: u64, burn_coin: Option<TypeName>, multiplier: u256): u64 {
        let burn_fee = if (is_burn_coin<CoinIn>(burn_coin)) fees.get_burn_amount(amount) else 0;
        let swap_fee = fees.get_swap_amount(amount - burn_fee, multiplier);
        amount - burn_fee - swap_fee
    }

    fun is_burn_coin<CoinIn>(mut burn_coin: Option<TypeName>): bool {
        if (burn_coin.is_some())
            type_name::get<CoinIn>() == burn_coin.extract()
        else 
            false
    }

    fun get_pool_data<CoinX, CoinY>(pool: &MemezPool): (u64, u64, u256, u256, Fees, Option<TypeName>) {
        let fees = pool.fees<CoinX, CoinY>();
        let balance_x = pool.balance_x<CoinX, CoinY>();
        let balance_y = pool.balance_y<CoinX, CoinY>();
        let burn_coin = pool.burn_coin<CoinX, CoinY>();
        let volume = pool.volume<CoinX, CoinY>();

        let multiplier_x = volume.multiplier_x();
        let multiplier_y = volume.multiplier_y();

        (balance_x, balance_y, multiplier_x, multiplier_y, fees, burn_coin)
    }
}