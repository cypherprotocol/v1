// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Script} from 'forge-std/Script.sol';

import {CypherRegistry} from "src/CypherRegistry.sol";

/// @notice A very simple deployment script
contract Deploy is Script {

  /// @notice The main script entrypoint
  /// @return cypherRegistry The deployed contract
  function run() external returns (CypherRegistry cypherRegistry) {
    vm.startBroadcast();
    cypherRegistry = new CypherRegistry();
    vm.stopBroadcast();
  }
}