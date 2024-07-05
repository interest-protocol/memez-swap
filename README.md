# [Memez Swap](https://www.memez.gg/)

 <p> <img width="50px"height="50px" src="./logo.png" /></p> 
 
 An AMM designed to safely pump Meme coins.

## Functionality

### Memez Swap

The Memez Swap allows users to deploy Meme Pools and earn trading fees. The pools only support swapping. They do not expose liquidity management functions. This means that it is impossible to rug as there is no LpCoin. The liquidity is always locked forever at deployment. In addition, the deployer earns all the trading fees, and no one else can add liquidity.

The DEX uses the famous `k = x * y` popularized by [Uniswap](https://uniswap.org/whitepaper.pdf).

It supports the following operations:

- Create Pool
- Swap
- Flash loans for extra fees.

Thats it!!

## Contracts

- [Sui](https://sui.io/) contracts: [sui-contracts]("./sui-contracts")

## Sui Contracts

### Quick Start

Make sure you have the latest version of the Sui binaries installed on your machine

[Instructions here](https://docs.sui.io/devnet/build/install)

#### Run tests

**To run the tests on the dex directory**

```bash
  cd sui-contracts
  sui move test
```

### Publish

```bash
  cd sui-contracts
  sui client publish --gas-budget 500000000
```

## Contact Us

- Twitter: [@interest_dinero](https://twitter.com/interest_dinero)
- Discord: https://discord.gg/interest
- Telegram: https://t.me/interestprotocol
- Email: [contact@interestprotocol.com](mailto:contact@interestprotocol.com)
- Medium: [@interestprotocol](https://medium.com/@interestprotocol)
