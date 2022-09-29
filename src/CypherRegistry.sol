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

  /// @dev Creates a new escrow for a protocol
  /// @param protocol The address of the contract to protect
  /// @param chainId The chain that the protocol smart contract originates from
  /// @param token The address of the token that is being stored in the protocols smart contracts
  /// @param tokenThreshold The amount per tx to limit on withdraw
  /// @param timeLimit How long the funds should stay locked up until release (if the team does not respond)
  /// @param oracles The addresses of the signers who can release the funds
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
