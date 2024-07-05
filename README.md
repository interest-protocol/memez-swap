# [Memez Swap](https://www.memez.gg/)

 <p> <img width="50px"height="50px" src="./logo.png" /></p> 
 
 An AMM designed to pump Meme coins on [Sui Network](https://sui.io/).  
  
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

### Meme Swap

The Memez Swap allows users to deploy Meme Pools and earn trading fees. The pools only support swapping. They do not have liquidity management functionality. This means that it is impossible to rug as there is no LpCoin. In addition, the deployer earns all the trading fees ad no one else can add liquidity to it.

The DEX uses the famous `k = x * y` popularized by [Uniswap](https://uniswap.org/whitepaper.pdf).

It supports the following operations:

- Create Pool
- Swap
- Flash loans for extra fees.

Thats it!!

## Contact Us

- Twitter: [@interest_dinero](https://twitter.com/interest_dinero)
- Discord: https://discord.gg/interest
- Telegram: https://t.me/interestprotocol
- Email: [contact@interestprotocol.com](mailto:contact@interestprotocol.com)
- Medium: [@interestprotocol](https://medium.com/@interestprotocol)
