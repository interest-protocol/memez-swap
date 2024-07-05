module amm::memez_amm_quote {

    use amm::{
        memez_amm_invariant,
        memez_amm_fees::Fees,
        memez_amm::InterestPool,
        memez_amm_utils::is_coin_x
    };

    public fun amount_out<CoinIn, CoinOut>(pool: &InterestPool, amount_in: u64): u64 { 

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut>(pool);

            memez_amm_invariant::get_amount_out(sub_fees_out(fees, amount_in), balance_x, balance_y)
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn>(pool);

            memez_amm_invariant::get_amount_out(sub_fees_out(fees, amount_in), balance_x, balance_y)
        }
  }

    public fun amount_in<CoinIn, CoinOut>(pool: &InterestPool, amount_out: u64): u64 {

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut>(pool);
            
            sub_fees_in(fees, memez_amm_invariant::get_amount_in(amount_out, balance_y, balance_x))
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn>(pool);
            
            sub_fees_in(fees, memez_amm_invariant::get_amount_in(amount_out, balance_y, balance_x))
        }
    }

    fun sub_fees_in(fees: Fees, amount: u64): u64 {
        fees.get_burn_amount_initial_amount(
            fees.get_swap_amount_initial_amount(amount)
        )
    }

    fun sub_fees_out(fees: Fees, amount: u64): u64 {
        let burn_fee = fees.get_burn_amount(amount);
        let swap_fee = fees.get_swap_amount(amount - burn_fee);
        amount - burn_fee - swap_fee
    }

    fun get_pool_data<CoinX, CoinY>(pool: &InterestPool): (u64, u64, Fees) {
        let fees = pool.fees<CoinX, CoinY>();
        let balance_x = pool.balance_x<CoinX, CoinY>();
        let balance_y = pool.balance_y<CoinX, CoinY>();

        (balance_x, balance_y, fees)
    }
}