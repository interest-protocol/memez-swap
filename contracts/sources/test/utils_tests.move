#[test_only]
module amm::utils_tests {
    use std::string::{utf8, to_ascii};

    use sui::{
        sui::SUI,
        coin::CoinMetadata,
        test_utils::assert_eq,
        test_scenario::{Self as test, next_tx, ctx}
    };

    use amm::{
        btc::BTC,
        eth::ETH,
        ipx_btce_eth::{Self, IPX_BTCE_ETH},
        ipx_btc_eth::{Self, IPX_BTC_ETH},
        deploy_utils::{scenario, people, deploy_coins},
        ipx_btc_eth_wrong_decimals::{Self, IPX_BTC_ETH_WRONG_DECIMALS},
        interest_amm_utils::{
            is_coin_x, 
            quote_liquidity,
            get_lp_coin_name,
            are_coins_ordered, 
            get_lp_coin_symbol,
            assert_lp_coin_integrity,
            get_optimal_add_liquidity, 
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
    fun test_get_optimal_add_liquidity() {
        let (x, y) = get_optimal_add_liquidity(5, 10, 0, 0);
        assert_eq(x, 5);
        assert_eq(y, 10);

        let (x, y) = get_optimal_add_liquidity(8, 4, 20, 30);
        assert_eq(x, 3);
        assert_eq(y, 4);

        let (x, y) = get_optimal_add_liquidity(15, 25, 50, 100);
        assert_eq(x, 13);
        assert_eq(y, 25);

        let (x, y) = get_optimal_add_liquidity(12, 18, 30, 20);
        assert_eq(x, 12);
        assert_eq(y, 8);

        let (x, y) = get_optimal_add_liquidity(9876543210,1234567890,987654,123456);
        assert_eq(x, 9876543210);
        assert_eq(y, 1234560402);

        let (x, y) = get_optimal_add_liquidity(999999999, 888888888, 777777777, 666666666);
        assert_eq(x, 999999999);
        assert_eq(y, 857142857);

        let (x, y) = get_optimal_add_liquidity(987654321, 9876543210, 123456, 987654);
        assert_eq(x, 987654321);
        assert_eq(y, 7901282569);
    }

    #[test]
    fun test_quote_liquidity() {
        assert_eq(quote_liquidity(10, 2, 5), 25);
        assert_eq(quote_liquidity(1000000, 100, 50000), 500000000);
        assert_eq(quote_liquidity(7, 7, 7), 7);
        assert_eq(quote_liquidity(0, 2, 100), 0);
        assert_eq(quote_liquidity(7, 3, 2), 5); // ~ 4.6
    }

    #[test]
    fun test_get_lp_coin_name() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice); 
        {
        let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
        let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);

        assert_eq(
            get_lp_coin_name<BTC, ETH>(
                &btc_metadata,
                &eth_metadata,
            ),
            utf8(b"Interest AMM Bitcoin Ether Lp Coin")
        );

        test::return_shared(btc_metadata);
        test::return_shared(eth_metadata);
        };

        test::end(scenario);
    }

    #[test]
    fun test_get_lp_coin_symbol() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice); 
        
        {
            let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
            let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);

            assert_eq(
                get_lp_coin_symbol<BTC, ETH>(
                    &btc_metadata,
                    &eth_metadata,
                ),
                to_ascii(utf8(b"ipx-BTC-ETH"))
            );

            test::return_shared(btc_metadata);
            test::return_shared(eth_metadata);
        };

        test::end(scenario);
    }

    #[test]
    fun test_assert_lp_coin_integrity() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_btc_eth::init_for_testing(ctx(test));
        };

        next_tx(test, alice); 
        {
            let metadata = test::take_shared<CoinMetadata<IPX_BTC_ETH>>(test);

            assert_lp_coin_integrity<BTC, ETH, IPX_BTC_ETH>(&metadata);

            test::return_shared(metadata);
        };

        test::end(scenario);    
    }

    #[test]
    #[expected_failure(abort_code = amm::interest_amm_errors::ELpCoinsMustHave9Decimals, location = amm::interest_amm_utils)]
    fun test_assert_lp_coin_integrity_wrong_decimal() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_btc_eth_wrong_decimals::init_for_testing(ctx(test));
        };

        next_tx(test, alice); 
        {
            let metadata = test::take_shared<CoinMetadata<IPX_BTC_ETH_WRONG_DECIMALS>>(test);

        assert_lp_coin_integrity<BTC, ETH, IPX_BTC_ETH_WRONG_DECIMALS>(&metadata);

        test::return_shared(metadata);
        };

        test::end(scenario);    
    }

    #[test]
    #[expected_failure(abort_code = amm::interest_amm_errors::ECoinsMustBeOrdered, location = amm::interest_amm_utils)]
    fun test_assert_lp_coin_integrity_wrong_coin_order() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_btc_eth_wrong_decimals::init_for_testing(ctx(test));
        };

        next_tx(test, alice); 
        {
        let metadata = test::take_shared<CoinMetadata<BTC>>(test);

        assert_lp_coin_integrity<ETH, BTC, BTC>(&metadata);

        test::return_shared(metadata);
        };

        test::end(scenario);    
    }

    #[test]
    #[expected_failure(abort_code = amm::interest_amm_errors::EWrongModuleName, location = amm::interest_amm_utils)]
    fun test_assert_lp_coin_integrity_wrong_lp_module_name() {
        let mut scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_btce_eth::init_for_testing(ctx(test));
        };

        next_tx(test, alice); 
        {
            let metadata = test::take_shared<CoinMetadata<IPX_BTCE_ETH>>(test);

            assert_lp_coin_integrity<BTC, ETH, IPX_BTCE_ETH>(&metadata);

            test::return_shared(metadata);
        };

        test::end(scenario);    
    }

    #[test]
    #[expected_failure]
    fun test_are_coins_ordered_same_coin() {
        are_coins_ordered<SUI, SUI>();
    }
}

#[test_only]
module amm::ipx_btc_eth_wrong_decimals {
    use sui::coin;

    public struct IPX_BTC_ETH_WRONG_DECIMALS has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: IPX_BTC_ETH_WRONG_DECIMALS, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            8, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(IPX_BTC_ETH_WRONG_DECIMALS {}, ctx);
    }  
}
