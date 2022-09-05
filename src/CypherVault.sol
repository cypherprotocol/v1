pragma solidity ^0.8.0;
import { CypherRegistry } from "./CypherRegistry.sol";

abstract contract CypherVault {
  address registry;
  address delegator;

  constructor(address _delegator, address _registry) {
    delegator = _delegator;
    registry = _registry;
  }

  function getEscrow() internal view returns (address) {
    return
      address(CypherRegistry(registry).getEscrowForProtocol(address(this)));
  }

  function getDelegator() external view returns (address) {
    return delegator;
  }
}
