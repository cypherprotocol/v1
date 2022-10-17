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
    address deployer;
    string protocolName;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProtocolCreated(address indexed registry, address indexed deployer, string protocolName);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _protocolName,
        address _deployer,
        address _registry
    ) {
        deployer = _deployer;
        registry = _registry;
        protocolName = _protocolName;

        emit ProtocolCreated(_registry, _deployer, _protocolName);
    }

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEscrow() internal view returns (address) {
        return address(CypherRegistry(registry).getEscrowForProtocol(address(this)));
    }

    function getDeployer() external view returns (address) {
        return deployer;
    }

    function getProtocolName() external view returns (string memory) {
        return protocolName;
    }
}
