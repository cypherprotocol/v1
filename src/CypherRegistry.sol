// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { CypherEscrow } from "./CypherEscrow.sol";
import { ICypherVault } from "./interfaces/ICypherVault.sol";

contract CypherRegistry {
  mapping(address => CypherEscrow) public getEscrowForProtocol;

  constructor() {}

  modifier delegatorOnly(address protocol) {
    require(ICypherVault(protocol).getDelegator() == msg.sender);
    _;
  }

  function createRateLimiter(
    address protocol,
    uint256 chainId,
    address token,
    uint256 tokenThreshold,
    uint256 timeLimit
  ) public delegatorOnly(protocol) {
    address[] memory managers = new address[](1);
    managers[0] = msg.sender;

    CypherEscrow escrow = new CypherEscrow(
      protocol,
      chainId,
      token,
      tokenThreshold,
      timeLimit,
      managers
    );
    getEscrowForProtocol[protocol] = escrow;
  }
}
