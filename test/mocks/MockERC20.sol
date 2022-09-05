// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
  constructor() ERC20("Test", "TEST", 18) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
