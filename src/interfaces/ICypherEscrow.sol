// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICypherEscrow {
  function escrowTokens(
    address to,
    address asset,
    uint256 amount,
    uint256 chainId_
  ) external;

  function escrowETH(
    address to,
    uint256 amount,
    uint256 chainId_
  ) external;
}
