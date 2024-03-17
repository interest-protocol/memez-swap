# [Interest Protocol am-AMM](https://www.suicoins.com/)

 <p> <img width="50px"height="50px" src="./logo.png" /></p> 
 
 An Auction-Managed AMM on [Sui Network](https://sui.io/).  
  
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

## Repo Structure

- **invariants:** It contains functions to calculate the invariant and swap amount out and in.
- **lib** A set of utility modules including math, comparator and string utilities.
- **test:** It has all test modules

## Functionality

### DEX

The Interest Protocol am-AMM DEX allows users to create pools, add/remove liquidity, and swap. The DEX runs a continuous English auction where _pool managers_ can rent the DEX liquidity to have the rights to set and receive all swap fees. Read more about it [here](https://arxiv.org/abs/2403.03367).

The DEX supports two types of pools denoted as:

- **Volatile:** `k = x * y` popularized by [Uniswap](https://uniswap.org/whitepaper.pdf)
- **Stable:** `k = yx^3 + xy^3` inspired by Curve's algorithm.

The DEX supports the following operations:

- Create Pool: Users can only create volatile & stable pools
- Add/Remove Liquidity
- Swap: Pool<BTC, Ether> | Ether -> BTC | BTC -> Ether
- Flash loans
- An auction to become the pool manager to earn and set the swap fees

## Contact Us

- Twitter: [@interest_dinero](https://twitter.com/interest_dinero)
- Discord: https://discord.gg/interest
- Telegram: https://t.me/interestprotocol
- Email: [contact@interestprotocol.com](mailto:contact@interestprotocol.com)
- Medium: [@interestprotocol](https://medium.com/@interestprotocol)
