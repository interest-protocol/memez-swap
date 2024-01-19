#[test_only]
module amm::eth {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct ETH has drop {}

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
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct BTC has drop {}

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
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct USDC has drop {}

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

#[test_only]
module amm::usdt {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct USDT has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: USDT, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<USDT>(
            witness, 
            9, 
            b"USDT",
            b"USD Tether", 
            b"Stable coin", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      transfer::public_share_object(metadata);
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(USDT {}, ctx);
  }
}

#[test_only]
module amm::ipx_v_btc_eth {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct IPX_V_BTC_ETH has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: IPX_V_BTC_ETH, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<IPX_V_BTC_ETH>(
            witness, 
            9, 
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
    init(IPX_V_BTC_ETH {}, ctx);
  }  
}

#[test_only]
module amm::ipx_v_eth_usdc {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct IPX_V_ETH_USDC has drop {}
    
  #[lint_allow(share_owned)]
  fun init(witness: IPX_V_ETH_USDC, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<IPX_V_ETH_USDC>(
            witness, 
            9, 
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
    init(IPX_V_ETH_USDC {}, ctx);
  }  
}

#[test_only]
module amm::ipx_s_usdc_usdt {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct IPX_S_USDC_USDT has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: IPX_S_USDC_USDT, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<IPX_S_USDC_USDT>(
            witness, 
            9, 
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
    init(IPX_S_USDC_USDT {}, ctx);
  }  
}

// * Invalid Coin

#[test_only]
module amm::ipx_btce_eth {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct IPX_BTCE_ETH has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: IPX_BTCE_ETH, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<IPX_BTCE_ETH>(
            witness, 
            9, 
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
    init(IPX_BTCE_ETH {}, ctx);
  }  
}