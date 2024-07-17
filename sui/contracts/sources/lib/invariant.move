module amm::memez_amm_invariant {

    use suitears::math256::div_up;

    use amm::memez_amm_errors as errors;

    public(package) fun invariant_(x: u64, y: u64): u256 {
        (x as u256) * (y as u256)
    }

    public(package) fun get_amount_in(coin_out_amount: u64, balance_in: u64, balance_out: u64): u64 {
        assert!(coin_out_amount != 0, errors::no_zero_coin());
        assert!(balance_in != 0 && balance_out != 0 && balance_out > coin_out_amount, errors::insufficient_liquidity());
        let (coin_out_amount, balance_in, balance_out) = (
            (coin_out_amount as u256),
            (balance_in as u256),
            (balance_out as u256)
        );

        let numerator = balance_in * coin_out_amount;
        let denominator = balance_out - coin_out_amount; 

        (div_up(numerator, denominator) as u64) 
    }

    public(package) fun get_amount_out(coin_in_amount: u64, balance_in: u64, balance_out: u64): u64 {
        assert!(coin_in_amount != 0, errors::no_zero_coin());
        assert!(balance_in != 0 && balance_out != 0, errors::insufficient_liquidity());
        let (coin_in_amount, balance_in, balance_out) = (
            (coin_in_amount as u256),
            (balance_in as u256),
            (balance_out as u256)
        );

        let numerator = balance_out * coin_in_amount;
        let denominator = balance_in + coin_in_amount; 

        ((numerator / denominator) as u64) 
  }
}