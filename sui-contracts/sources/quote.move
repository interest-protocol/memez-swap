module amm::interest_amm_quote {

    use amm::{
        interest_amm_invariant,
        interest_amm_fees::Fees,
        interest_amm::InterestPool,
        interest_amm_utils::is_coin_x
    };

    public fun amount_out<CoinIn, CoinOut>(pool: &InterestPool, amount_in: u64): u64 { 

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut>(pool);
            let amount_in = amount_in - fees.get_fee_in_amount(amount_in);

            get_amount_out(fees, interest_amm_invariant::get_amount_out(amount_in, balance_x, balance_y))
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn>(pool);
            let amount_in = amount_in - fees.get_fee_in_amount(amount_in);

            get_amount_out(fees, interest_amm_invariant::get_amount_out(amount_in, balance_y, balance_x))
        }
  }

    public fun amount_in<CoinIn, CoinOut>(pool: &InterestPool, amount_out: u64): u64 {

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut>(pool);
            let amount_out = fees.get_fee_out_initial_amount(amount_out);

            fees.get_fee_in_initial_amount(interest_amm_invariant::get_amount_in(amount_out, balance_x, balance_y))
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn>(pool);
            let amount_out = fees.get_fee_out_initial_amount(amount_out);

            fees.get_fee_in_initial_amount(interest_amm_invariant::get_amount_in(amount_out, balance_y, balance_x))
        }
    }

    fun get_amount_out(fees: Fees, amount_out: u64): u64 {
        let fee_amount = fees.get_fee_out_amount(amount_out);
        amount_out - fee_amount
    }

    fun get_pool_data<CoinX, CoinY>(pool: &InterestPool): (u64, u64, Fees) {
        let fees = pool.fees<CoinX, CoinY>();
        let balance_x = pool.balance_x<CoinX, CoinY>();
        let balance_y = pool.balance_y<CoinX, CoinY>();

        (balance_x, balance_y, fees)
    }
}