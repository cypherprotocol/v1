// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { CypherEscrow } from "./CypherEscrow.sol";
import { ICypherProtocol } from "./interfaces/ICypherProtocol.sol";

contract CypherRegistry {
  mapping(address => CypherEscrow) public getEscrowForProtocol;

  constructor() {}

  modifier architectOnly(address protocol) {
    require(ICypherProtocol(protocol).getArchitect() == msg.sender);
    _;
  }

  function createRateLimiter(
    address protocol,
    uint256 chainId,
    address token,
    uint256 tokenThreshold,
    uint256 timeLimit
  ) public architectOnly(protocol) {
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
