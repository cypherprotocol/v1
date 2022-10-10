// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICypherEscrow {
    function escrowTokens(
        address origin,
        address dst,
        address asset,
        uint256 amount
    ) external;

    function escrowETH(address origin, address dst) external payable;
}
