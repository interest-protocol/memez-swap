module amm::interest_amm_utils {

    use std::{
        ascii,
        type_name,
        string::{Self, String}
    };

    use sui::coin::CoinMetadata;

    use suitears::{
        comparator,
        math64::mul_div_up
    };

    use amm::interest_amm_errors as errors;

    public fun are_coins_ordered<CoinA, CoinB>(): bool {
        let coin_a_type_name = type_name::get<CoinA>();
        let coin_b_type_name = type_name::get<CoinB>();
    
        assert!(coin_a_type_name != coin_b_type_name, errors::select_different_coins());
    
        comparator::compare(&coin_a_type_name, &coin_b_type_name).lt()
    }

    public fun is_coin_x<CoinA, CoinB>(): bool {
        comparator::compare(&type_name::get<CoinA>(), &type_name::get<CoinB>()).lt()
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
    ): String {
        let coin_x_name = coin_x_metadata.get_name();
        let coin_y_name = coin_y_metadata.get_name();

        let mut expected_lp_coin_name = string::utf8(b"");

        expected_lp_coin_name.append_utf8(b"Interest AMM ");
        expected_lp_coin_name.append_utf8(*coin_x_name.bytes());
        expected_lp_coin_name.append_utf8(b" ");
        expected_lp_coin_name.append_utf8(*coin_y_name.bytes());
        expected_lp_coin_name.append_utf8(b" Lp Coin");

        expected_lp_coin_name
    }

    public fun get_lp_coin_symbol<CoinX, CoinY>(
        coin_x_metadata: &CoinMetadata<CoinX>,
        coin_y_metadata: &CoinMetadata<CoinY>,
    ): ascii::String {
        let coin_x_symbol = coin_x_metadata.get_symbol();
        let coin_y_symbol = coin_y_metadata.get_symbol();

        let mut expected_lp_coin_symbol = string::utf8(b"");

        expected_lp_coin_symbol.append_utf8(b"ipx-");
        expected_lp_coin_symbol.append_utf8(ascii::into_bytes(coin_x_symbol));
        expected_lp_coin_symbol.append_utf8(b"-");
        expected_lp_coin_symbol.append_utf8(coin_y_symbol.into_bytes());

        expected_lp_coin_symbol.to_ascii()
    }

    public fun assert_lp_coin_integrity<CoinX, CoinY, LpCoin>(lp_coin_metadata: &CoinMetadata<LpCoin>) {
        assert!(lp_coin_metadata.get_decimals() == 9, errors::lp_coins_must_have_9_decimals());
        assert_lp_coin_otw<CoinX, CoinY, LpCoin>()
    }

    fun assert_lp_coin_otw<CoinX, CoinY, LpCoin>() {
        assert!(are_coins_ordered<CoinX, CoinY>(), errors::coins_must_be_ordered());
        let coin_x_module_name = type_name::get<CoinX>().get_module();
        let coin_y_module_name = type_name::get<CoinY>().get_module();
        let lp_coin_module_name = type_name::get<LpCoin>().get_module();

        let mut expected_lp_coin_module_name = string::utf8(b"");

        expected_lp_coin_module_name.append_utf8(b"ipx_");
        expected_lp_coin_module_name.append_utf8(coin_x_module_name.into_bytes());
        expected_lp_coin_module_name.append_utf8(b"_");
        expected_lp_coin_module_name.append_utf8(coin_y_module_name.into_bytes());

        assert!(
            comparator::compare(&lp_coin_module_name, &expected_lp_coin_module_name.to_ascii()).eq(), 
            errors::wrong_module_name()
        );
  }
}