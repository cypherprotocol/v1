pragma solidity ^0.8.0;
import { CypherRegistry } from "./CypherRegistry.sol";

abstract contract CypherProtocol {
  address registry;
  address architect;

  constructor(address _architect, address _registry) {
    architect = _architect;
    registry = _registry;
  }

  function getEscrow() internal view returns (address) {
    return
      address(CypherRegistry(registry).getEscrowForProtocol(address(this)));
  }

  function getArchitect() external view returns (address) {
    return architect;
  }
}
