module amm::interest_amm_utils {

    use std::type_name;

    use suitears::comparator;

    use amm::interest_amm_errors as errors;

    public(package) fun are_coins_ordered<CoinA, CoinB>(): bool {
        let coin_a_type_name = type_name::get<CoinA>();
        let coin_b_type_name = type_name::get<CoinB>();
    
        assert!(coin_a_type_name != coin_b_type_name, errors::select_different_coins());
    
        comparator::compare(&coin_a_type_name, &coin_b_type_name).lt()
    }

    public(package) fun is_coin_x<CoinA, CoinB>(): bool {
        comparator::compare(&type_name::get<CoinA>(), &type_name::get<CoinB>()).lt()
    }
}