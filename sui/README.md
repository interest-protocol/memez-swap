## Sui Contracts

### Quick Start

Make sure you have the latest version of the Sui binaries installed on your machine

[Instructions here](https://docs.sui.io/devnet/build/install)

#### Run tests

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
