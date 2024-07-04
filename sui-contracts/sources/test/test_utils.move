#[test_only]
module amm::deploy_utils {

    use sui::{
        coin::{mint_for_testing, TreasuryCap, CoinMetadata},
        test_scenario::{Self as test, Scenario, next_tx, ctx}
    };

    use amm::{
        btc::{Self, BTC},
        eth::{Self, ETH},
        usdc::{Self, USDC},
        interest_amm::{Self, Registry},
        ipx_btc_eth::{Self, IPX_BTC_ETH},
        ipx_eth_usdc::{Self, IPX_ETH_USDC},
    };

    public fun deploy_coins(test: &mut Scenario) {
        let (alice, _) = people();

        next_tx(test, alice);
        {
            btc::init_for_testing(ctx(test));
            eth::init_for_testing(ctx(test));
            usdc::init_for_testing(ctx(test));
        };
    }

    public fun deploy_eth_usdc_pool(test: &mut Scenario, eth_amount: u64, usdc_amount: u64) {
        let (alice, _) = people();

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_eth_usdc::init_for_testing(ctx(test));
        };

        next_tx(test, alice);
        
        {
            let mut registry = test::take_shared<Registry>(test);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_ETH_USDC>>(test);
            let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
            let mut lp_coin_metadata = test::take_shared<CoinMetadata<IPX_ETH_USDC>>(test);
      
            let lp_coin = interest_amm::new(
                &mut registry,
                mint_for_testing<ETH>(eth_amount, ctx(test)),
                mint_for_testing<USDC>(usdc_amount, ctx(test)),
                lp_coin_cap,
                &eth_metadata,
                &usdc_metadata,
                &mut lp_coin_metadata,
                ctx(test)
            );

            transfer::public_transfer(lp_coin, alice);

            test::return_shared(eth_metadata);
            test::return_shared(usdc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
    }

    public fun deploy_btc_eth_pool(test: &mut Scenario, btc_amount: u64, eth_amount: u64) {
        let (alice, _) = people();

        deploy_coins(test);

        next_tx(test, alice);
        {
            ipx_btc_eth::init_for_testing(ctx(test));
        };

        next_tx(test, alice);
        
        {
            let mut registry = test::take_shared<Registry>(test);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_BTC_ETH>>(test);
            let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
            let eth_metadata = test::take_shared<CoinMetadata<ETH>>(test);
            let mut lp_coin_metadata = test::take_shared<CoinMetadata<IPX_BTC_ETH>>(test);
      
            let lp_coin = interest_amm::new(
                &mut registry,
                mint_for_testing<BTC>(btc_amount, ctx(test)),
                mint_for_testing<ETH>(eth_amount, ctx(test)),
                lp_coin_cap,
                &btc_metadata,
                &eth_metadata,
                &mut lp_coin_metadata,
                ctx(test)
            );

            transfer::public_transfer(lp_coin, alice);

            test::return_shared(eth_metadata);
            test::return_shared(btc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
    }

    public fun scenario(): Scenario { test::begin(@0x1) }

    public fun people():(address, address) { (@0xBEEF, @0x1337)}
}