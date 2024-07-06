#[test_only]
module amm::deploy_utils {

    use sui::{
        coin::mint_for_testing,
        test_scenario::{Self as test, Scenario, next_tx, ctx}
    };

    use amm::{
        btc::{Self, BTC},
        eth::{Self, ETH},
        usdc::{Self, USDC},
        memez_amm_admin::{Self, Admin},
        memez_amm::{Self, MemezPool, Registry},
    };

    const BURN_FEE: u256 = 150_000_000_000_000_000; // 15%

    public fun set_up(test: &mut Scenario) {
        let (alice, _) = people();

        next_tx(test, alice);
        {
            btc::init_for_testing(ctx(test));
            eth::init_for_testing(ctx(test));
            usdc::init_for_testing(ctx(test));
            memez_amm_admin::init_for_testing(ctx(test));
        };
    }

    public fun deploy_eth_usdc_pool(test: &mut Scenario, eth_amount: u64, usdc_amount: u64) {
        let (alice, _) = people();

        set_up(test);

        next_tx(test, alice);
        
        {
            let mut registry = test::take_shared<Registry>(test);
      
            let deployer_nft = memez_amm::new(
                &mut registry,
                mint_for_testing<ETH>(eth_amount, ctx(test)),
                mint_for_testing<USDC>(usdc_amount, ctx(test)),
                ctx(test)
            );

            transfer::public_transfer(deployer_nft, alice);

            test::return_shared(registry);
        };
    }

    public fun deploy_btc_eth_pool(test: &mut Scenario, btc_amount: u64, eth_amount: u64) {
        let (alice, _) = people();

        set_up(test);

        next_tx(test, alice);
        {
            let mut registry = test::take_shared<Registry>(test);
      
            let deployer_nft = memez_amm::new(
                &mut registry,
                mint_for_testing<BTC>(btc_amount, ctx(test)),
                mint_for_testing<ETH>(eth_amount, ctx(test)),
                ctx(test)
            );

            transfer::public_transfer(deployer_nft, alice);

            test::return_shared(registry);
        };

        next_tx(test, alice);
        {
            let admin = test.take_from_sender<Admin>();

             let mut pool = test.take_shared<MemezPool>();

            pool.update_fees<BTC, ETH>(&admin, option::none(), option::some(BURN_FEE), option::none(), option::none());

            test.return_to_sender(admin);
            test::return_shared(pool);
        };
    }

    public fun scenario(): Scenario { test::begin(@0x1) }

    public fun people():(address, address) { (@0xBEEF, @0x1337)}
}