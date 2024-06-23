# [Interest Protocol AMM](https://www.suicoins.com/)

 <p> <img width="50px"height="50px" src="./logo.png" /></p> 
 
 An AMM on [Sui Network](https://sui.io/).  
  
## Quick start  
  
Make sure you have the latest version of the Sui binaries installed on your machine

[Instructions here](https://docs.sui.io/devnet/build/install)

### Run tests

**To run the tests on the dex directory**

```bash
  cd contracts
  sui move test
```

### Publish

```bash
  cd contracts
  sui client publish --gas-budget 500000000
```

## Functionality

### DEX

The Interest Protocol AMM DEX allows users to create pools, add/remove liquidity, and swap. The DEX issues a NFT that accrues trading fees and LpCoins that represent the underlying liquidity to LPs.

The DEX uses the famous `k = x * y` popularized by [Uniswap](https://uniswap.org/whitepaper.pdf).

The DEX supports the following operations:

- Create Pool: Users can only create volatile & stable pools
- Add/Remove Liquidity
- Swap: Pool<BTC, Ether> | Ether -> BTC | BTC -> Ether
- Flash loans

## Contact Us

- Twitter: [@interest_dinero](https://twitter.com/interest_dinero)
- Discord: https://discord.gg/interest
- Telegram: https://t.me/interestprotocol
- Email: [contact@interestprotocol.com](mailto:contact@interestprotocol.com)
- Medium: [@interestprotocol](https://medium.com/@interestprotocol)
