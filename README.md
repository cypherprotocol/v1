# 🔐 cypher • [![ci](https://github.com/bmwoolf/cypher-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/bmwoolf/cypher-contracts/actions/workflows/ci.yml) ![license](https://img.shields.io/github/license/bmwoolf/cypher-contracts?label=license) ![solidity](https://img.shields.io/badge/solidity-^0.8.15-lightgrey)

Introducing Cypher, an on-chain security system to help prevent hacks. Integrate with all of your other preferred protocols and monitoring services.

[Website](https://limiter-mu.vercel.app/)

Deploy your contracts through our frontend with your custom parameters, extend our EscrowContract, and add these lines to your withdraw function:

```solidity
import {CypherProtocol} from "../../src/CypherProtocol.sol";

contract MockProtocol is CypherProtocol {
    constructor(address architect, address registry) CypherProtocol("MockProtocol", architect, registry) {}
}
```

```solidity
ICypherEscrow escrow = ICypherEscrow(getEscrow());
escrow.escrowETH{ value: ethBalances[msg.sender] }(msg.sender, msg.sender, 1);
```

From there, select how you want to be communicated with:

- Twitter
- Discord
- Telegram
- Cell
- Email

## Features

- [ ] Check against flashbots (MEV)
- [x] Reentrancy protection mechanism
  - [x] ETH deposited reentrancy
  - [x] ERC20 deposited reentrancy
- [x] Testing Suite
  - [x] ETH deposited reentrancy
  - [x] ERC20 deposited reentrancy
- [ ] onERC721Received
- [ ] onERC1155Received

## Testing hacks

Exploit: `forge test -vv`

## Checklist

Ensure you completed **all of the steps** below before submitting your pull request:

- [ ] Ran `forge snapshot`?
- [ ] Ran `npm run lint`?
- [ ] Ran `forge test`?

## Commits

- ♻️ refactor
- 📝 docs
- ✨ feat
- 👷‍♂️ edit
- 🎨 cleanup
- ⚡️ gas optimize

## Blueprint

```ml
lib
├─ forge-std — https://github.com/foundry-rs/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
scripts
├─ Deploy.s.sol — Simple Deployment Script
src
├─ CypherEscrow — Core escrow contract for your protocol
├─ CypherProtocol — The interface for your contracts
├─ CypherRegistry — Database of all registered Cypher contracts
test
└─ CypherVault.t — Exhaustive tests for ETH based reentrancy hacks
└─ CypherVaultERC20.t — Exhaustive tests for ERC20 based reentrancy hacks
```

## Development

**Setup**

```bash
forge install
```

**Building**

```bash
forge build
```

**Testing**

```bash
forge test
```

**Deployment & Verification**

Inside the [`utils/`](./utils/) directory are a few preconfigured scripts that can be used to deploy and verify contracts.

Scripts take inputs from the cli, using silent mode to hide any sensitive information.

_NOTE: These scripts are required to be \_executable_ meaning they must be made executable by running `chmod +x ./utils/*`.\_

_NOTE: these scripts will prompt you for the contract name and deployed addresses (when verifying). Also, they use the `-i` flag on `forge` to ask for your private key for deployment. This uses silent mode which keeps your private key from being printed to the console (and visible in logs)._

### First time with Forge/Foundry?

See the official Foundry installation [instructions](https://github.com/foundry-rs/foundry/blob/master/README.md#installation).

Then, install the [foundry](https://github.com/foundry-rs/foundry) toolchain installer (`foundryup`) with:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Now that you've installed the `foundryup` binary,
anytime you need to get the latest `forge` or `cast` binaries,
you can run `foundryup`.

So, simply execute:

```bash
foundryup
```

🎉 Foundry is installed! 🎉

### Writing Tests with Foundry

With [Foundry](https://github.com/foundry-rs/foundry), all tests are written in Solidity! 🥳

Create a test file for your contract in the `test/` directory.

For example, [`src/Greeter.sol`](./src/Greeter.sol) has its test file defined in [`./test/Greeter.t.sol`](./test/Greeter.t.sol).

To learn more about writing tests in Solidity for Foundry, reference Rari Capital's [solmate](https://github.com/Rari-Capital/solmate/tree/main/src/test) repository created by [@transmissions11](https://twitter.com/transmissions11).

### Configure Foundry

Using [foundry.toml](./foundry.toml), Foundry is easily configurable.

For a full list of configuration options, see the Foundry [configuration documentation](https://github.com/foundry-rs/foundry/blob/master/config/README.md#all-options).

## License

[AGPL-3.0-only](https://github.com/abigger87/femplate/blob/master/LICENSE)

## Acknowledgements

- [femplate](https://github.com/abigger87/femplate)
- [foundry](https://github.com/foundry-rs/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [forge-template](https://github.com/foundry-rs/forge-template)
- [foundry-toolchain](https://github.com/foundry-rs/foundry-toolchain)

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
