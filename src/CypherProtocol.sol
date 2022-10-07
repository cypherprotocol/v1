// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {CypherRegistry} from "./CypherRegistry.sol";

/// @title Cypher Escrow Protocol
/// @author bmwoolf
/// @author zksoju
/// @notice A skeleton for a protocol contract when creating a new escrow
abstract contract CypherProtocol {

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL STATE
    //////////////////////////////////////////////////////////////*/

    address registry;
    address architect;
    string protocolName;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _protocolName,
        address _architect,
        address _registry
    ) {
        architect = _architect;
        registry = _registry;
        protocolName = _protocolName;
    }

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEscrow() internal view returns (address) {
        return address(CypherRegistry(registry).getEscrowForProtocol(address(this)));
    }

    function getArchitect() external view returns (address) {
        return architect;
    }

    function getProtocolName() external view returns (string memory) {
        return protocolName;
    }
}
