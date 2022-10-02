// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {Attack} from "./exploits/ETHReentrancy/Attack.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract CypherVaultETHTest is BaseCypherTest {
    Attack attackContract;
    DAOWallet vulnerableContract;

    SafeDAOWallet safeWallet;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(carol);
        vulnerableContract = new DAOWallet();

        // Deposit ETH into non-Cypher, vulnerable contract
        vm.startPrank(alice);
        vulnerableContract.deposit{value: 100}();
        vm.stopPrank();

        safeWallet = new SafeDAOWallet(dave, address(registry));

        _assignEscrowAsArchitect(address(safeWallet));

        // Deposit ETH into contract protected by Cypher
        vm.startPrank(bob);
        safeWallet.deposit{value: 100}();
        vm.stopPrank();
    }

    //////////////////////////// ETH ////////////////////////////
    // function testSetUpAttackETH() public {
    //     startHoax(hacker, 1 ether);
    //     assertEq(address(vulnerableContract).balance, 100 ether);

    //     attackContract = new Attack(payable(address(vulnerableContract)));
    //     attackContract.attack{value: 1 ether}();

    //     assertEq(address(vulnerableContract).balance, 0);
    //     assertEq(hacker.balance, 101 ether);
    //     vm.stopPrank();
    // }

    // function testETHWithdrawEscrowStopped() public {
    //     // when pulling over threshold, it works. not less than
    //     startHoax(hacker, 10);
    //     assertEq(address(safeWallet).balance, 200);
    //     // hacker withdraws from patchContract
    //     attackContract = new Attack(payable(address(safeWallet)));
    //     // gets stopped
    //     vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));
    //     attackContract.attack{value: 10}();
    //     // check to make sure he cannot withdraw on his own
    //     assertEq(hacker.balance, 10);
    //     vm.stopPrank();
    // }

    // function testETHWithdrawNewWhaleStoppedCypherApproves() public {
    //     // when pulling over threshold, it works. not less than
    //     startHoax(newWhale, 100);
    //     assertEq(address(safeWallet).balance, 200);
    //     // gets stopped, deposit and withdraw more than threshold
    //     safeWallet.deposit{value: 65}();
    //     safeWallet.withdrawETH();

    //     // check to make sure he cannot withdraw on his own
    //     assertEq(newWhale.balance, 35);

    //     bytes32 key = keccak256(abi.encodePacked(address(safeWallet), newWhale, uint256(0)));
    //     (, uint256 amount) = escrow.getTransaction(key);
    //     assertEq(amount, 65);
    //     vm.stopPrank();

    //     // cypher team releases
    //     startHoax(cypher); // cypher EOA
    //     escrow.acceptTransaction(key);
    //     assertEq(newWhale.balance, 100);
    // }

    // function testETHWithdrawStoppedCypherDenies() public {
    //     startHoax(hacker, 100);
    //     assertEq(address(safeWallet).balance, 200);
    //     // hacker withdraws from patchContract
    //     attackContract = new Attack(payable(address(safeWallet)));
    //     // gets stopped, deposit and withdraw more than threshold
    //     // TODO: make this a hack, not deposit
    //     safeWallet.deposit{value: 65}();
    //     safeWallet.withdrawETH();

    //     // check to make sure he cannot withdraw on his own
    //     bytes32 key = keccak256(abi.encodePacked(address(safeWallet), hacker, uint256(0)));
    //     (, uint256 amount) = escrow.getTransaction(key);

    //     assertEq(hacker.balance, 35);
    //     assertEq(amount, 65);
    //     vm.stopPrank();

    //     // cypher team denies
    //     startHoax(cypher); // cypher EOA

    //     escrow.denyTransaction(key);
    //     // protocol balance should get the funds back + hacker deposited funds
    //     assertEq(address(safeWallet).balance, 265);
    //     assertEq(hacker.balance, 35);
    //     vm.stopPrank();
    // }

    // function testETHWithdrawStoppedProtocolApproves() public {
    //     startHoax(newWhale, 100);
    //     assertEq(address(safeWallet).balance, 200);
    //     // newWhale withdraws from patchContract
    //     attackContract = new Attack(payable(address(safeWallet)));
    //     // gets stopped, deposit and withdraw more than threshold
    //     // TODO: make this a hack, not deposit
    //     safeWallet.deposit{value: 65}();
    //     safeWallet.withdrawETH();

    //     bytes32 key = keccak256(abi.encodePacked(address(safeWallet), newWhale, uint256(0)));
    //     (, uint256 amount) = escrow.getTransaction(key);

    //     // check to make sure he cannot withdraw on his own
    //     assertEq(newWhale.balance, 35);
    //     assertEq(amount, 65);
    //     vm.stopPrank();

    //     // architect approves
    //     startHoax(architect); // cypher EOA
    //     escrow.acceptTransaction(key);
    //     assertEq(newWhale.balance, 100);
    // }

    // function testETHWithdrawStoppedProtocolDenies() public {
    //     startHoax(hacker, 100);
    //     assertEq(address(safeWallet).balance, 200);
    //     // hacker withdraws from patchContract
    //     attackContract = new Attack(payable(address(safeWallet)));
    //     // gets stopped, deposit and withdraw more than threshold
    //     // TODO: make this a hack, not deposit
    //     safeWallet.deposit{value: 65}();
    //     safeWallet.withdrawETH();

    //     bytes32 key = keccak256(abi.encodePacked(address(safeWallet), hacker, uint256(0)));
    //     (, uint256 amount) = escrow.getTransaction(key);

    //     // check to make sure he cannot withdraw on his own
    //     assertEq(hacker.balance, 35);
    //     assertEq(amount, 65);
    //     vm.stopPrank();

    //     // protocol approves
    //     startHoax(architect);

    //     escrow.denyTransaction(key);
    //     // protocol balance should get the funds back + hacker deposited funds
    //     assertEq(address(safeWallet).balance, 265);
    //     assertEq(hacker.balance, 35);
    //     vm.stopPrank();
    // }

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
