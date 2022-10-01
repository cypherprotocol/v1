// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICypherEscrow {
    function escrowTokens(
        address from,
        address to,
        address asset,
        uint256 amount
    ) external;

    function escrowETH(address from, address to) external payable;
}
