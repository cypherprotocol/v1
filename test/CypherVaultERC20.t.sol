// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { CypherEscrow } from "../src/CypherEscrow.sol";
import { AttackToken } from "./exploit/ERC20/Attacktoken.sol";
import { DAOWallet } from "./exploit/DAOWallet.sol";
import { SafeDAOWallet } from "./exploit/SafeDAOWallet.sol";
import { CypherRegistry } from "../src/CypherRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { Bool } from "./lib/BoolTool.sol";

contract CypherVaultTest is Test {
  AttackToken attackTokenContract;
  DAOWallet vulnerableContract;
  SafeDAOWallet patchedContract;
  CypherEscrow escrow;
  CypherRegistry registry;
  MockERC20 token;

  address hacker = address(0xBEEF);
  address architect = address(0xDEAD);
  address whale = address(0x1337);
  address cypher = address(0x1111);
  address newWhale = address(0x9088);

  function setUp() public {
    // Create new ERC20 and issue to all users
    token = new MockERC20();
    token.mint(hacker, 100);
    token.mint(architect, 100);
    token.mint(whale, 100);
    token.mint(cypher, 100);

    // Deploy the protocol to escrow registry
    registry = new CypherRegistry();

    // Deposit ERC20 into non-Cypher, vulnerable contract
    startHoax(hacker, hacker);
    vulnerableContract = new DAOWallet();
    token.approve(address(vulnerableContract), 100);
    vulnerableContract.deposit(address(token), 100);
    vm.stopPrank();

    // Deposit ERC20 into contract protected by Cypher
    startHoax(architect, architect);
    patchedContract = new SafeDAOWallet(architect, address(registry));
    token.approve(address(patchedContract), 100);
    patchedContract.depositTokens(address(token), 100);

    address[] memory oracles = new address[](2);
    oracles[0] = architect;
    oracles[1] = cypher;

    // Deploy escrow contract from designated architect
    escrow = CypherEscrow(
      registry.createEscrow(
        address(patchedContract),
        1,
        address(token),
        50,
        1 days,
        oracles
      )
    );

    address[] memory whales = new address[](1);
    whales[0] = whale;

    escrow.addToWhitelist(whales);
    vm.stopPrank();

    startHoax(whale, whale);
    patchedContract.deposit{ value: 100 }();
    token.approve(address(patchedContract), 100);
    patchedContract.depositTokens(address(token), 100);
    vm.stopPrank();
  }

  function testBalances() public {
    assertEq(token.balanceOf(address(vulnerableContract)), 100);
    assertEq(token.balanceOf(address(patchedContract)), 100);
  }

  // deposit ERC20 as collateral (can be USDC), get ETH back
  function testHackToken() public {
    emit log_string("new test");
  }
}