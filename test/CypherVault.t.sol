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

  address hacker = address(0xBEEF);
  address architect = address(0xDEAD);
  address whale = address(0x1337);
  address cypher = address(0x1111);

  MockERC20 token;

  function setUp() public {
    // Create new ERC20 and issue to all users
    token = new MockERC20();
    token.mint(hacker, 100);
    token.mint(architect, 100);
    token.mint(whale, 100);
    token.mint(cypher, 100);

    // Deploy the protocol to escrow registry
    registry = new CypherRegistry();

    // Deposit ETH and ERC20 into non-Cypher, vulnerable contract
    startHoax(hacker, hacker);
    vulnerableContract = new DAOWallet();
    // vulnerableContract.deposit{ value: 100 }();
    vulnerableContract.deposit{ value: 100 ether }();
    token.approve(address(vulnerableContract), 100);
    vulnerableContract.deposit(address(token), 100);
    vm.stopPrank();

    // Deposit ETH and ERC20 into contract protected by Cypher
    startHoax(architect, architect);
    patchedContract = new SafeDAOWallet(architect, address(registry));
    patchedContract.deposit{ value: 100 }();
    token.approve(address(patchedContract), 100);
    patchedContract.deposit(address(token), 100);

    address[] memory oracles = new address[](1);
    oracles[0] = architect;

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
    patchedContract.deposit(address(token), 100);
    vm.stopPrank();
  }

  function testMetadata() public {
    assertEq(escrow.isWhitelisted(whale), true);
  }

  function testBalances() public {
    assertEq(vulnerableContract.balanceOf(hacker), 100 ether); // needs to be in ether for reentrancy
    assertEq(patchedContract.balanceOf(architect), 100);

    assertEq(vulnerableContract.balanceOf(hacker, address(token)), 100);
    assertEq(patchedContract.balanceOf(architect, address(token)), 100);
  }

  /* HACKER FLOWS */
  // ETH
  function testSetUpAttackETH() public {
    startHoax(hacker, 1 ether);
    assertEq(vulnerableContract.getContractBalance(), 100 ether);

    attackContract = new Attack(payable(address(vulnerableContract)));
    attackContract.attack{ value: 1 ether }();

    assertEq(vulnerableContract.getContractBalance(), 0);
    assertEq(hacker.balance, 101 ether);
    vm.stopPrank();
  }

  function testETHWithdrawStoppedCypherApproves() public {
    // when pulling over threshold, it works. not less than
    startHoax(hacker, 10);
    assertEq(patchedContract.getContractBalance(), 200);
    // hacker withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped (hopefully)
    vm.expectRevert(bytes("TRANSFER_FAILED"));
    attackContract.attack{ value: 10 }();
    // check to make sure he cannot withdraw on his own
    assertEq(hacker.balance, 10);
    // cypher team releases
    vm.stopPrank();
  }

  function testETHWithdrawStoppedCypherDenies() public {}

  function testETHWithdrawStoppedProtocolApproves() public {}

  function testETHWithdrawStoppedProtocolDenies() public {}

  // ERC20
  function testERC20WithdrawStoppedCypherApproves() public {}

  function testERC20WithdrawStoppedCypherDenies() public {}

  function testERC20WithdrawStoppedProtocolApproves() public {}

  function testERC20WithdrawStoppedProtocolDenies() public {}

  // Multiple ERC20's
  function testMultipleERC20WithdrawStoppedCypherApproves() public {}

  function testMultipleERC20WithdrawStoppedCypherDenies() public {}

  function testMultipleERC20WithdrawStoppedProtocolApproves() public {}

  function testMultipleERC20WithdrawStoppedProtocolDenies() public {}

  /* WHALE FLOWS */
  function testWithdrawETHIfWhitelisted() public {
    uint256 prevBalance = whale.balance;

    vm.prank(whale);
    patchedContract.withdrawETH();

    assertEq(whale.balance, prevBalance + 100);
  }

  function testWithdrawERC20IfWhitelisted() public {
    uint256 prevBalance = token.balanceOf(whale);

    vm.prank(whale);
    patchedContract.withdraw(address(token), 51);

    assertEq(token.balanceOf(whale), prevBalance + 51);
  }

  function testWithdrawMultipleERC20IfWhitelisted() public {}

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
  function testOnlySourceContractModifierERC20() public {}

  // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
  function testCannotNonSourceContractCallModifierERC20() public {}

  // stores correct Transaction information
  function testStoresCorrectTransactionInformationERC20() public {}

  // emits AmountStopped if stopped
  function testEmitAmountStoppedEventERC20() public {}

  // escrowETH
  // escrows the correct amount of tokens
  function testCorrectAmountOfETHEscrowed() public {}

  // only allows calls from the source contract
  function testOnlySourceContractModifierETH() public {}

  // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
  function testCannotNonSourceContractCallModifierETH() public {}

  // stores correct Transaction information
  function testStoresCorrectTransactionInformationETH() public {}

  // emits AmountStopped if stopped
  function testEmitAmountStoppedEventETH() public {}

  // CypherVault
  // gets the correct escrow
  function testGetsCorrectEscrow() public {}

  // gets the correct delegator
  function testGetsCorrectDelegator() public {}

  // sets the correct escrow
  function testSetsCorrectEscrow() public {}

  // sets the correct delegator
  function testSetsCorrectDelegator() public {}

  // CypherRegistry
  // creates the rate limiter with the correct variables
  function testSetsCorrectEscrowInformation() public {}

  // does not allow anyone but the delegator to deploy (scoped to protocol address and delegator)
  function testCannotAnyoneButDelegatorDeployContract() public {}

  /* FULL WALK THROUGH */
  function testFullWalkThrough() public {}

  /* UTILS  */
  function userHacksWithReentrancy() public {
    // run Attack on unsafe dao
    //
  }
}
