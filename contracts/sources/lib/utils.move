module sc_dex::utils {
  use std::ascii;
  use std::type_name;
  use std::string::{Self, String};

  use sui::coin::{Self, CoinMetadata};

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

  public fun get_optimal_add_liquidity(
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

  public fun get_lp_coin_name<CoinX, CoinY>(
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,  
    volatile: bool
  ): String {
    let coin_x_name = coin::get_name(coin_x_metadata);
    let coin_y_name = coin::get_name(coin_y_metadata);

    let expected_lp_coin_name = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_name, b"sc ");
    string::append_utf8(&mut expected_lp_coin_name, if (volatile) b"volatile " else b"stable ");
    string::append_utf8(&mut expected_lp_coin_name, *string::bytes(&coin_x_name));
    string::append_utf8(&mut expected_lp_coin_name, b" ");
    string::append_utf8(&mut expected_lp_coin_name, *string::bytes(&coin_y_name));
    string::append_utf8(&mut expected_lp_coin_name, b" Lp Coin");
    expected_lp_coin_name
  }

  public fun get_lp_coin_symbol<CoinX, CoinY>(
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,
    volatile: bool  
  ): ascii::String {
    let coin_x_symbol = coin::get_symbol(coin_x_metadata);
    let coin_y_symbol = coin::get_symbol(coin_y_metadata);

    let expected_lp_coin_symbol = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_symbol, b"sc-");
    string::append_utf8(&mut expected_lp_coin_symbol, if (volatile) b"v-" else b"s-");
    string::append_utf8(&mut expected_lp_coin_symbol, ascii::into_bytes(coin_x_symbol));
    string::append_utf8(&mut expected_lp_coin_symbol, b"-");
    string::append_utf8(&mut expected_lp_coin_symbol, ascii::into_bytes(coin_y_symbol));
    string::to_ascii(expected_lp_coin_symbol)
  }

  public fun assert_lp_coin_integrity<CoinX, CoinY, LpCoin>(lp_coin_metadata: &CoinMetadata<LpCoin>, volatile: bool) {
     assert!(coin::get_decimals(lp_coin_metadata) == 9, errors::lp_coins_must_have_9_decimals());
     assert_lp_coin_otw<CoinX, CoinY, LpCoin>(volatile)
  }

  fun assert_lp_coin_otw<CoinX, CoinY, LpCoin>(volatile: bool) {
    assert!(are_coins_ordered<CoinX, CoinY>(), errors::coins_must_be_ordered());
    let coin_x_module_name = type_name::get_module(&type_name::get<CoinX>());
    let coin_y_module_name = type_name::get_module(&type_name::get<CoinY>());
    let lp_coin_module_name = type_name::get_module(&type_name::get<LpCoin>());

    let expected_lp_coin_module_name = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_module_name, b"sc_");
    string::append_utf8(&mut expected_lp_coin_module_name, if (volatile) b"v_" else b"s_");
    string::append_utf8(&mut expected_lp_coin_module_name, ascii::into_bytes(coin_x_module_name));
    string::append_utf8(&mut expected_lp_coin_module_name, b"_");
    string::append_utf8(&mut expected_lp_coin_module_name, ascii::into_bytes(coin_y_module_name));

    assert!(
      comparator::is_equal(&comparator::compare(&lp_coin_module_name, &string::to_ascii(expected_lp_coin_module_name))), 
      errors::wrong_module_name()
    );
  }
}