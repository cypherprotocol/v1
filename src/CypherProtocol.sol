pragma solidity ^0.8.0;
import {CypherRegistry} from "./CypherRegistry.sol";

abstract contract CypherProtocol {
    address registry;
    address architect;
    string protocolName;

    constructor(
        string memory _protocolName,
        address _architect,
        address _registry
    ) {
        architect = _architect;
        registry = _registry;
        protocolName = _protocolName;
    }

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
