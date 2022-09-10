// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";

import { MockERC20 } from "../test/mocks/MockERC20.sol";

/// @notice A very simple deployment script
contract Mint is Script {
  /// @notice The main script entrypoint
  /// @return mockERC20 The deployed contract
  function run() external returns (MockERC20 mockERC20) {
    vm.startBroadcast();
    mockERC20 = MockERC20(0xa521659F7a144D110C702A62054d3b20950744E7);
    mockERC20.mint(msg.sender, 1 ether);
    vm.stopBroadcast();
  }
}
