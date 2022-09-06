// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { CypherEscrow } from "../src/CypherEscrow.sol";
import { Attack } from "./exploit/Attack.sol";
import { DAOWallet } from "./exploit/DAOWallet.sol";
import { SafeDAOWallet } from "./exploit/SafeDAOWallet.sol";
import { CypherRegistry } from "../src/CypherRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract CypherVaultTest is Test {
  Attack attackContract;
  DAOWallet vulnerableContract;
  SafeDAOWallet patchedContract;
  CypherEscrow escrow;
  CypherRegistry registry;

  address alice = address(0xBEEF);
  address bob = address(0xDEAD);
  address charlie = address(0x1337);

  MockERC20 token;

  function setUp() public {
    // Create new ERC20 and issue to all users
    token = new MockERC20();
    token.mint(alice, 100);
    token.mint(bob, 100);
    token.mint(charlie, 100);

    // Deploy the protocol to escrow registry
    registry = new CypherRegistry();

    // Deposit ETH and ERC20 into non-Cypher wallet
    startHoax(alice, alice);
    vulnerableContract = new DAOWallet();
    vulnerableContract.deposit{ value: 100 }();
    token.approve(address(vulnerableContract), 100);
    vulnerableContract.deposit(address(token), 100);
    vm.stopPrank();

    // Deposit ETH and ERC20 into Cypher wallet
    startHoax(bob, bob);
    patchedContract = new SafeDAOWallet(bob, address(registry));
    patchedContract.deposit{ value: 100 }();
    token.approve(address(patchedContract), 100);
    patchedContract.deposit(address(token), 100);

    // Deploy escrow contract from designated architect
    escrow = CypherEscrow(
      registry.createEscrow(
        address(patchedContract),
        1,
        address(token),
        50,
        1 days
      )
    );

    address[] memory whales = new address[](1);
    whales[0] = charlie;

    escrow.addToWhitelist(whales);
    vm.stopPrank();

    startHoax(charlie, charlie);
    patchedContract.deposit{ value: 100 }();
    token.approve(address(patchedContract), 100);
    patchedContract.deposit(address(token), 100);
    vm.stopPrank();

    // attackContract = new Attack(payable(address(vulnerableContract)));
  }

  function testMetadata() public {
    assertEq(escrow.isWhitelisted(charlie), true);
  }

  function testBalances() public {
    assertEq(vulnerableContract.balanceOf(alice), 100);
    assertEq(patchedContract.balanceOf(bob), 100);

    assertEq(vulnerableContract.balanceOf(alice, address(token)), 100);
    assertEq(patchedContract.balanceOf(bob, address(token)), 100);
  }

  /* HACKER FLOWS */
  // ETH
  function testETHWithdrawWhaleApprovedPassthrough() public {}
  function testETHWithdrawStoppedCypherApproves() public {}
  function testETHWithdrawStoppedCypherDenies() public {}
  function testETHWithdrawStoppedProtocolApproves() public {}
  function testETHWithdrawStoppedProtocolDenies() public {}
  // ERC20
  function testERC20WithdrawStoppedCypherApproves() public {}
  function testERC20WithdrawStoppedCypherDenies() public {}
  function testERC20WithdrawStoppedProtocolApproves() public {}
  function testERC20WithdrawStoppedProtocolDenies() public {}
  // Multiple ERC20's
  function testMultipleERC20WhaleApprovedPassthrough() public {}
  function testMultipleERC20WithdrawStoppedCypherApproves() public {}
  function testMultipleERC20WithdrawStoppedCypherDenies() public {}
  function testMultipleERC20WithdrawStoppedProtocolApproves() public {}
  function testMultipleERC20WithdrawStoppedProtocolDenies() public {}

  /* WHALE FLOWS */
  function testWithdrawETHIfWhitelisted() public {
    uint256 prevBalance = charlie.balance;

    vm.prank(charlie);
    patchedContract.withdraw(51 wei);

    assertEq(charlie.balance, prevBalance + 51);
  }

  function testWithdrawERC20IfWhitelisted() public {
    uint256 prevBalance = token.balanceOf(charlie);

    vm.prank(charlie);
    patchedContract.withdraw(address(token), 51);

    assertEq(token.balanceOf(charlie), prevBalance + 51);
  }

  function testWithdrawETHIfBelowThreshold() public {}

  function testWithdrawERC20IfBelowThreshold() public {}

  function testCannotWithdrawETHIfRevokedByOracle() public {}

  function testCannotWithdrawERC20IfRevokedByOracle() public {}

  function testCannotHackerWithdrawERC20WithMultipleOracles() public {}

  /* CONTRACTS */
  // CypherEscrow
    function testCypherEscrowConstructorVariablesSetCorrectly() public {}
  // escrowTokens
    // escrows the correct amount of tokens
    function testEscrowsCorrectAmountOfTokens() public {}
    // only allows calls from the source contract
    function testOnlySourceContractModifier() public {}
    // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
    function testCannotNonSourceContractCallModifier() public {}
    // stores correct Transaction information
    function testStoresCorrectTransactionInformation() public {}
    // emits AmountStopped if stopped
    function testEmitAmountStoppedEvent() public {}
  // escrowETH
    // escrows the correct amount of tokens
    // only allows calls from the source contract
    // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
    // stores correct Transaction information
    // emits AmountStopped if stopped
  // CypherVault
    // gets the correct escrow
    // gets the correct delegator
    // sets the correct escrow
    // sets the correct delegator
  // CypherRegistry
    // creates the rate limiter with the correct variables
    // does not allow anyone but the delegator to deploy (scoped to protocol address and delegator)
}
