module amm::interest_amm_quote {

    use suitears::math64::{min, mul_div_down};

    use amm::{
        interest_amm_invariant,
        interest_amm_fees::Fees,
        interest_amm::InterestPool,
        interest_amm_utils::{get_optimal_add_liquidity, is_coin_x}
    };

    public fun amount_out<CoinIn, CoinOut, LpCoin>(pool: &InterestPool, amount_in: u64): u64 { 

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut, LpCoin>(pool);
            let amount_in = amount_in - fees.get_fee_in_amount(amount_in);

            get_amount_out(fees, interest_amm_invariant::get_amount_out(amount_in, balance_x, balance_y))
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn, LpCoin>(pool);
            let amount_in = amount_in - fees.get_fee_in_amount(amount_in);

            get_amount_out(fees, interest_amm_invariant::get_amount_out(amount_in, balance_y, balance_x))
        }
  }

    public fun amount_in<CoinIn, CoinOut, LpCoin>(pool: &InterestPool, amount_out: u64): u64 {

        if (is_coin_x<CoinIn, CoinOut>()) {
            let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut, LpCoin>(pool);
            let amount_out = fees.get_fee_out_initial_amount(amount_out);

            fees.get_fee_in_initial_amount(interest_amm_invariant::get_amount_in(amount_out, balance_x, balance_y))
        } else {
            let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn, LpCoin>(pool);
            let amount_out = fees.get_fee_out_initial_amount(amount_out);

            fees.get_fee_in_initial_amount(interest_amm_invariant::get_amount_in(amount_out, balance_y, balance_x))
        }
    }

    public fun add_liquidity<CoinX, CoinY, LpCoin>(
        pool: &InterestPool,
        amount_x: u64,
        amount_y: u64
    ): (u64, u64, u64) {
        let balance_x = pool.balance_x<CoinX, CoinY, LpCoin>();
        let balance_y = pool.balance_y<CoinX, CoinY, LpCoin>();
        let supply = pool.lp_coin_supply<CoinX, CoinY, LpCoin>();

        let (optimal_x_amount, optimal_y_amount) = get_optimal_add_liquidity(
            amount_x,
            amount_y,
            balance_x,
            balance_y
        );

        let share_to_mint = min(
            mul_div_down(optimal_x_amount, supply, balance_x),
            mul_div_down(optimal_y_amount, supply, balance_y)
        );

        (share_to_mint, optimal_x_amount, optimal_y_amount)
    }

    public fun remove_liquidity<CoinX, CoinY, LpCoin>(
        pool: &InterestPool,
        amount: u64
    ): (u64, u64) {
        let balance_x = pool.balance_x<CoinX, CoinY, LpCoin>();
        let balance_y = pool.balance_y<CoinX, CoinY, LpCoin>();
        let supply = pool.lp_coin_supply<CoinX, CoinY, LpCoin>();
    
        let amount_x = mul_div_down(amount, balance_x, supply);
        let amount_y = mul_div_down(amount, balance_y, supply);

        (
            amount_x,
            amount_y
        )
  }

    fun get_amount_out(fees: Fees, amount_out: u64): u64 {
        let fee_amount = fees.get_fee_out_amount(amount_out);
        amount_out - fee_amount
    }

    fun get_pool_data<CoinX, CoinY, LpCoin>(pool: &InterestPool): (u64, u64, Fees) {
        let fees = pool.fees<CoinX, CoinY, LpCoin>();
        let balance_x = pool.balance_x<CoinX, CoinY, LpCoin>();
        let balance_y = pool.balance_y<CoinX, CoinY, LpCoin>();

        (balance_x, balance_y, fees)
    }
}