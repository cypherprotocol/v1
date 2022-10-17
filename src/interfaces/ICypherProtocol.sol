// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICypherProtocol {
    function getDeployer() external view returns (address);

    function getEscrow() external view returns (address);

    function getProtocolName() external view returns (string memory);
}
