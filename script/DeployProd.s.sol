// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";

import {CypherRegistry} from "../src/CypherRegistry.sol";
import {SafeDAOWallet} from "../test/mocks/SafeDAOWallet.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    /// @notice The main script entrypoint
    /// @return cypherRegistry The deployed contract
    function run() external returns (CypherRegistry cypherRegistry) {
        vm.startBroadcast();
        MockERC20 mockERC20 = new MockERC20();
        SafeDAOWallet daoWallet = new SafeDAOWallet(
            address(msg.sender),
            address(0xa5ca58d6b97c711f1fff656aaf7429a26a738186)
        );

        vm.stopBroadcast();
    }
}
