# [Sui Coins](https://www.suicoins.com/)

 <p> <img width="50px"height="50px" src="./logo.png" /></p> 
 
 AMM DEX on [Sui](https://sui.io/) Network.  
  
## Quick start  
  
Make sure you have the latest version of the Sui binaries installed on your machine

[Instructions here](https://docs.sui.io/devnet/build/install)

## Install the Prover

```bash
  mkdir move_lang && cd move_lang
  git clone https://github.com/move-language/move.git
  cd move
  ./scripts/dev_setup.sh -yp
  . ~/.profile
```

### Run tests

**To run the tests on the dex directory**

```bash
  cd contracts
  sui move test
```

**To run the prover**

```bash
  cd contracts
  sui move prove
```

Only the UniV2 invariant has been formally verified.

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

The Sui Coins DEX allows users to create pools, add/remove liquidity and swap.

The DEX supports two types of pools denoted as:

- **Volatile:** `k = x * y` popularized by [Uniswap](https://uniswap.org/whitepaper.pdf)
- **Stable:** `k = yx^3 + xy^3` inspired by Curve's algorithm.

- Create Pool: Users can only create volatile & stable pools
- Add/Remove Liquidity
- Swap: Pool<BTC, Ether> | Ether -> BTC | BTC -> Ether
- Flash loans

## Contact Us

- Twitter: [@interest_dinero](https://twitter.com/interest_dinero)
- Discord: https://discord.gg/interestprotocol
- Telegram: https://t.me/interestprotocol
- Email: [contact@interestprotocol.com](mailto:contact@interestprotocol.com)
- Medium: [@interestprotocol](https://medium.com/@interestprotocol)
