// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { CypherEscrow } from "../src/CypherEscrow.sol";
import { Attack } from "./exploit/Attack.sol";
import { AttackToken } from "./exploit/ERC20/Attacktoken.sol";
import { DAOWallet } from "./exploit/DAOWallet.sol";
import { SafeDAOWallet } from "./exploit/SafeDAOWallet.sol";
import { CypherRegistry } from "../src/CypherRegistry.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { Bool } from "./lib/BoolTool.sol";

contract CypherVaultTest is Test {
  Attack attackContract;
  AttackToken attackTokenContract;
  DAOWallet vulnerableContract;
  SafeDAOWallet patchedContract;
  CypherEscrow escrow;
  CypherRegistry registry;

  address hacker = address(0xBEEF);
  address architect = address(0xDEAD);
  address whale = address(0x1337);
  address cypher = address(0x1111);
  address newWhale = address(0x9088);

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

  function testMetadata() public {
    assertEq(escrow.isWhitelisted(whale), true);
  }

  function testBalances() public {
    assertEq(vulnerableContract.balanceOf(hacker), 100 ether); // needs to be in ether for reentrancy
    assertEq(patchedContract.balanceOf(architect), 100);

    assertEq(vulnerableContract.balanceOf(hacker, address(token)), 100);
    assertEq(patchedContract.balanceOf(architect, address(token)), 100);
  }

  //////////////////////////// ETH ////////////////////////////
  function testSetUpAttackETH() public {
    startHoax(hacker, 1 ether);
    assertEq(vulnerableContract.getContractBalance(), 100 ether);

    attackContract = new Attack(payable(address(vulnerableContract)));
    attackContract.attack{ value: 1 ether }();

    assertEq(vulnerableContract.getContractBalance(), 0);
    assertEq(hacker.balance, 101 ether);
    vm.stopPrank();
  }

  function testETHWithdrawEscrowStopped() public {
    // when pulling over threshold, it works. not less than
    startHoax(hacker, 10);
    assertEq(patchedContract.getContractBalance(), 200);
    // hacker withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped (hopefully)
    vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));
    attackContract.attack{ value: 10 }();
    // check to make sure he cannot withdraw on his own
    assertEq(hacker.balance, 10);
    vm.stopPrank();
  }

  function testETHWithdrawNewWhaleStoppedCypherApproves() public {
    // when pulling over threshold, it works. not less than
    startHoax(newWhale, 100);
    assertEq(patchedContract.getContractBalance(), 200);
    // whale withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped, deposit and withdraw more than threshold
    patchedContract.deposit{ value: 65 }();
    patchedContract.withdrawETH();

    // check to make sure he cannot withdraw on his own
    assertEq(newWhale.balance, 35);
    assertEq(escrow.getWalletBalance(newWhale), 65);
    vm.stopPrank();

    // cypher team releases
    startHoax(cypher); // cypher EOA
    escrow.approveWithdraw(newWhale);
    escrow.releaseTokens(newWhale, address(0x0));
    assertEq(newWhale.balance, 100);
  }

  function testETHWithdrawStoppedCypherDenies() public {
    startHoax(hacker, 100);
    assertEq(patchedContract.getContractBalance(), 200);
    // hacker withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped, deposit and withdraw more than threshold
    // TODO: make this a hack, not deposit
    patchedContract.deposit{ value: 65 }();
    patchedContract.withdrawETH();

    // check to make sure he cannot withdraw on his own
    assertEq(hacker.balance, 35);
    assertEq(escrow.getWalletBalance(hacker), 65);
    vm.stopPrank();

    // cypher team denies
    startHoax(cypher); // cypher EOA

    bool approvalStatusBefore = escrow.getApprovalStatus(hacker);
    assertEq(approvalStatusBefore, false);
    escrow.disapproveWithdraw(hacker);
    bool approvalStatusAfter = escrow.getApprovalStatus(hacker);
    assertEq(approvalStatusAfter, false);

    escrow.denyTransaction(hacker);
    // protocol balance should get the funds back + hacker deposited funds
    assertEq(patchedContract.getContractBalance(), 265);
    assertEq(hacker.balance, 35);
    vm.stopPrank();
  }

  function testETHWithdrawStoppedProtocolApproves() public {
    startHoax(newWhale, 100);
    assertEq(patchedContract.getContractBalance(), 200);
    // newWhale withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped, deposit and withdraw more than threshold
    // TODO: make this a hack, not deposit
    patchedContract.deposit{ value: 65 }();
    patchedContract.withdrawETH();

    // check to make sure he cannot withdraw on his own
    assertEq(newWhale.balance, 35);
    assertEq(escrow.getWalletBalance(newWhale), 65);
    vm.stopPrank();

    // architect approves
    startHoax(architect); // cypher EOA
    escrow.approveWithdraw(newWhale);
    escrow.releaseTokens(newWhale, address(0x0));
    assertEq(newWhale.balance, 100);
  }

  function testETHWithdrawStoppedProtocolDenies() public {
    startHoax(hacker, 100);
    assertEq(patchedContract.getContractBalance(), 200);
    // hacker withdraws from patchContract
    attackContract = new Attack(payable(address(patchedContract)));
    // gets stopped, deposit and withdraw more than threshold
    // TODO: make this a hack, not deposit
    patchedContract.deposit{ value: 65 }();
    patchedContract.withdrawETH();

    // check to make sure he cannot withdraw on his own
    assertEq(hacker.balance, 35);
    assertEq(escrow.getWalletBalance(hacker), 65);
    vm.stopPrank();

    // protocol approves
    startHoax(architect);
    bool approvalStatusBefore = escrow.getApprovalStatus(hacker);
    assertEq(approvalStatusBefore, false);
    escrow.disapproveWithdraw(hacker);
    bool approvalStatusAfter = escrow.getApprovalStatus(hacker);
    assertEq(approvalStatusAfter, false);

    escrow.denyTransaction(hacker);
    // protocol balance should get the funds back + hacker deposited funds
    assertEq(patchedContract.getContractBalance(), 265);
    assertEq(hacker.balance, 35);
    vm.stopPrank();
  }

  /* CONTRACTS */
  // CypherEscrow
  // function testCypherEscrowConstructorVariablesSetCorrectly() public {}

  // // escrowTokens
  // // escrows the correct amount of tokens
  // function testEscrowsCorrectAmountOfTokens() public {}

  // // only allows calls from the source contract
  // function testOnlySourceContractModifierERC20() public {}

  // // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
  // function testCannotNonSourceContractCallModifierERC20() public {}

  // // stores correct Transaction information
  // function testStoresCorrectTransactionInformationERC20() public {}

  // // emits AmountStopped if stopped
  // function testEmitAmountStoppedEventERC20() public {}

  // // escrowETH
  // // escrows the correct amount of tokens
  // function testCorrectAmountOfETHEscrowed() public {}

  // // only allows calls from the source contract
  // function testOnlySourceContractModifierETH() public {}

  // // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
  // function testCannotNonSourceContractCallModifierETH() public {}

  // // stores correct Transaction information
  // function testStoresCorrectTransactionInformationETH() public {}

  // // emits AmountStopped if stopped
  // function testEmitAmountStoppedEventETH() public {}

  // // CypherVault
  // // gets the correct escrow
  // function testGetsCorrectEscrow() public {}

  // // gets the correct delegator
  // function testGetsCorrectDelegator() public {}

  // // sets the correct escrow
  // function testSetsCorrectEscrow() public {}

  // // sets the correct delegator
  // function testSetsCorrectDelegator() public {}

  // // CypherRegistry
  // // creates the rate limiter with the correct variables
  // function testSetsCorrectEscrowInformation() public {}

  // // does not allow anyone but the delegator to deploy (scoped to protocol address and delegator)
  // function testCannotAnyoneButDelegatorDeployContract() public {}
}
