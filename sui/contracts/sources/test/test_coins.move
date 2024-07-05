#[test_only]
module amm::eth {
    use sui::coin;

    public struct ETH has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: ETH, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<ETH>(
            witness, 
            9, 
            b"ETH",
            b"Ether", 
            b"Ethereum Native Coin", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ETH {}, ctx);
    }
}

#[test_only]
module amm::btc {
    use sui::coin;

    public struct BTC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: BTC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BTC>(
            witness, 
            9, 
            b"BTC",
            b"Bitcoin", 
            b"Bitcoin Native Coin", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC {}, ctx);
    }
}

#[test_only]
module amm::usdc {
    use sui::coin;

    public struct USDC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: USDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<USDC>(
            witness, 
            6, 
            b"USDC",
            b"USD Coin", 
            b"USD Stable Coin by Circle", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDC {}, ctx);
    }
}