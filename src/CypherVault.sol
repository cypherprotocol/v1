// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract CypherVault {
  address delegator;

  constructor(address _delegator) {
    delegator = _delegator;
  }

  function getDelegator() external view returns (address) {
    return delegator;
  }
}
