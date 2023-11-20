module sc_dex::quote {

  use sc_dex::stable;
  use sc_dex::volatile;
  use sc_dex::curves::is_volatile;
  use sc_dex::math64::{min, mul_div_down};
  use sc_dex::sui_coins_amm::{Self, SuiCoinsPool};
  use sc_dex::utils::{calculate_optimal_add_liquidity, is_coin_x};

  public fun quote_amount_out<CoinIn, CoinOut, LpCoin>(pool: &SuiCoinsPool, amount_in: u64): u64 { 
    if (is_coin_x<CoinIn, CoinOut>()) {
       let balance_x = sui_coins_amm::balance_x<CoinIn, CoinOut, LpCoin>(pool);
       let balance_y = sui_coins_amm::balance_y<CoinIn, CoinOut, LpCoin>(pool);
      if (sui_coins_amm::volatile<CoinIn, CoinOut, LpCoin>(pool)) {
        volatile::get_amount_out(amount_in, balance_x, balance_y)
      } else {
        let decimals_x = sui_coins_amm::decimals_x<CoinIn, CoinOut, LpCoin>(pool);
        let decimals_y = sui_coins_amm::decimals_y<CoinIn, CoinOut, LpCoin>(pool);
        let k = stable::invariant_(balance_x, balance_y, decimals_x, decimals_y);
        stable::get_amount_out(k, amount_in, balance_x, balance_y, decimals_x, decimals_y, true)
      }
    } else {
        let balance_x = sui_coins_amm::balance_x<CoinOut, CoinIn, LpCoin>(pool);
       let balance_y = sui_coins_amm::balance_y<CoinOut, CoinIn, LpCoin>(pool);
      if (sui_coins_amm::volatile<CoinOut, CoinIn, LpCoin>(pool)) {
        volatile::get_amount_out(amount_in, balance_y, balance_x)
      } else {
        let decimals_x = sui_coins_amm::decimals_x<CoinOut, CoinIn, LpCoin>(pool);
        let decimals_y = sui_coins_amm::decimals_y<CoinOut, CoinIn, LpCoin>(pool);
        let k = stable::invariant_(balance_x, balance_y, decimals_x, decimals_y);
        stable::get_amount_out(k, amount_in, balance_x, balance_y, decimals_x, decimals_y, false)
      }
    }
  }

  public fun quote_amount_in<CoinIn, CoinOut, LpCoin>(pool: &SuiCoinsPool, amount_out: u64): u64 {
    if (is_coin_x<CoinIn, CoinOut>()) {
       let balance_x = sui_coins_amm::balance_x<CoinIn, CoinOut, LpCoin>(pool);
       let balance_y = sui_coins_amm::balance_y<CoinIn, CoinOut, LpCoin>(pool);
      if (sui_coins_amm::volatile<CoinIn, CoinOut, LpCoin>(pool)) {
        volatile::get_amount_in(amount_out, balance_x, balance_y)
      } else {
        let decimals_x = sui_coins_amm::decimals_x<CoinIn, CoinOut, LpCoin>(pool);
        let decimals_y = sui_coins_amm::decimals_y<CoinIn, CoinOut, LpCoin>(pool);
        let k = stable::invariant_(balance_x, balance_y, decimals_x, decimals_y);
        stable::get_amount_in(k, amount_out, balance_x, balance_y, decimals_x, decimals_y, true)
      }
    } else {
        let balance_x = sui_coins_amm::balance_x<CoinOut, CoinIn, LpCoin>(pool);
       let balance_y = sui_coins_amm::balance_y<CoinOut, CoinIn, LpCoin>(pool);
      if (sui_coins_amm::volatile<CoinOut, CoinIn, LpCoin>(pool)) {
        volatile::get_amount_in(amount_out, balance_y, balance_x)
      } else {
        let decimals_x = sui_coins_amm::decimals_x<CoinOut, CoinIn, LpCoin>(pool);
        let decimals_y = sui_coins_amm::decimals_y<CoinOut, CoinIn, LpCoin>(pool);
        let k = stable::invariant_(balance_x, balance_y, decimals_x, decimals_y);
        stable::get_amount_in(k, amount_out, balance_x, balance_y, decimals_x, decimals_y, false)
      }
    }
  }

  public fun quote_add_liquidity<CoinX, CoinY, LpCoin>(
    pool: &SuiCoinsPool,
    amount_x: u64,
    amount_y: u64
  ): (u64, u64, u64) {
    let balance_x = sui_coins_amm::balance_x<CoinX, CoinY, LpCoin>(pool);
    let balance_y = sui_coins_amm::balance_y<CoinX, CoinY, LpCoin>(pool);
    let supply = sui_coins_amm::lp_coin_supply<CoinX, CoinY, LpCoin>(pool);

    let (optimal_x_amount, optimal_y_amount) = calculate_optimal_add_liquidity(
      amount_x,
      amount_y,
      balance_x,
      balance_y
    );

    let share_to_mint = min(
      mul_div_down(amount_x, supply, balance_x),
      mul_div_down(amount_y, supply, balance_y)
    );

    (share_to_mint, optimal_x_amount, optimal_y_amount)
  }

  public fun quote_remove_liquidity<CoinX, CoinY, LpCoin>(
    pool: &SuiCoinsPool,
    amount: u64
  ): (u64, u64) {
    let balance_x = sui_coins_amm::balance_x<CoinX, CoinY, LpCoin>(pool);
    let balance_y = sui_coins_amm::balance_y<CoinX, CoinY, LpCoin>(pool);
    let supply = sui_coins_amm::lp_coin_supply<CoinX, CoinY, LpCoin>(pool);

    (
      mul_div_down(amount, balance_x, supply),
      mul_div_down(amount, balance_y, supply)
    )
  }

}