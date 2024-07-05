#[test_only]
module amm::utils_tests {

    use sui::{
        sui::SUI,
        test_utils::assert_eq,
    };

    use amm::{
        eth::ETH,
        memez_amm_utils::{
            is_coin_x, 
            are_coins_ordered 
        }
    };

    public struct ABC {}

    public struct CAB {}

    #[test]
    fun test_are_coins_ordered() {
        assert_eq(are_coins_ordered<SUI, ABC>(), true);
        assert_eq(are_coins_ordered<ABC, SUI>(), false);
        assert_eq(are_coins_ordered<ABC, CAB>(), true);
        assert_eq(are_coins_ordered<CAB, ABC>(), false);
    }

    #[test]
    fun test_is_coin_x() {
        assert_eq(is_coin_x<SUI, ABC>(), true);
        assert_eq(is_coin_x<ABC, SUI>(), false);
        assert_eq(is_coin_x<ABC, CAB>(), true);
        assert_eq(is_coin_x<CAB, ABC>(), false);
        // does not throw
        assert_eq(is_coin_x<ETH, ETH>(), false);
    }

    #[test]
    #[expected_failure]
    fun test_are_coins_ordered_same_coin() {
        are_coins_ordered<SUI, SUI>();
    }
}
