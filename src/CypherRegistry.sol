// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { CypherEscrow } from "./CypherEscrow.sol";
import { ICypherProtocol } from "./interfaces/ICypherProtocol.sol";

contract CypherRegistry {
  event EscrowCreated(
    address indexed escrow,
    address indexed protocol,
    uint256 chainId,
    address token,
    uint256 tokenThreshold,
    uint256 timeLimit,
    address[] oracles
  );

  mapping(address => CypherEscrow) public getEscrowForProtocol;

  constructor() {}

  modifier architectOnly(address protocol) {
    require(ICypherProtocol(protocol).getArchitect() == msg.sender);
    _;
  }

  function createEscrow(
    address protocol,
    uint256 chainId,
    address token,
    uint256 tokenThreshold,
    uint256 timeLimit,
    address[] memory oracles
  ) public architectOnly(protocol) returns (address) {
    CypherEscrow escrow = new CypherEscrow(
      protocol,
      chainId,
      token,
      tokenThreshold,
      timeLimit,
      oracles
    );
    getEscrowForProtocol[protocol] = escrow;

    emit EscrowCreated(
      address(escrow),
      protocol,
      chainId,
      token,
      tokenThreshold,
      timeLimit,
      oracles
    );

    return address(escrow);
  }
}
