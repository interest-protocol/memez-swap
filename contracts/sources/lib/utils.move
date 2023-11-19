module sc_dex::utils {
  use std::type_name;

  use sc_dex::errors;
  use sc_dex::comparator;
  use sc_dex::math64::mul_div_up;
  
  public fun are_coins_ordered<CoinA, CoinB>(): bool {
    let coin_a_type_name = type_name::get<CoinA>();
    let coin_b_type_name = type_name::get<CoinB>();
    
    assert!(coin_a_type_name != coin_b_type_name, errors::select_different_coins());
    
    comparator::is_smaller_than(&comparator::compare(&coin_a_type_name, &coin_b_type_name))
  }

  public fun is_coin_x<CoinA, CoinB>(): bool {
    comparator::is_smaller_than(&comparator::compare(&type_name::get<CoinA>(), &type_name::get<CoinB>()))
  }

  public fun calculate_optimal_add_liquidity(
    desired_amount_x: u64,
    desired_amount_y: u64,
    reserve_x: u64,
    reserve_y: u64
  ): (u64, u64) {

    if (reserve_x == 0 && reserve_y == 0) return (desired_amount_x, desired_amount_y);

    let optimal_y_amount = quote_liquidity(desired_amount_x, reserve_x, reserve_y);
    if (desired_amount_y >= optimal_y_amount) return (desired_amount_x, optimal_y_amount);

    let optimal_x_amount = quote_liquidity(desired_amount_y, reserve_y, reserve_x);
    (optimal_x_amount, desired_amount_y)
  } 

  public fun quote_liquidity(amount_a: u64, reserves_a: u64, reserves_b: u64): u64 {
    mul_div_up(amount_a, reserves_b, reserves_a)
  }
}