// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";

import {CypherRegistry} from "../src/CypherRegistry.sol";
import {SafeDAOWallet} from "../test/exploits/SafeDAOWallet.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    /// @notice The main script entrypoint
    /// @return cypherRegistry The deployed contract
    function run() external returns (CypherRegistry cypherRegistry) {
        vm.startBroadcast();
        cypherRegistry = new CypherRegistry();
        MockERC20 mockERC20 = new MockERC20();
        SafeDAOWallet daoWallet = new SafeDAOWallet(address(msg.sender), address(cypherRegistry));

        address[] memory oracles = new address[](1);
        oracles[0] = msg.sender;
        cypherRegistry.createEscrow(address(daoWallet), 1, address(mockERC20), 100, 1 days, oracles);
        vm.stopBroadcast();
    }
}
