// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {Attack} from "./exploits/ETHReentrancy/Attack.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {CypherEscrow} from "../src/CypherEscrow.sol";

contract CypherEscrowETHTest is BaseCypherTest {
    Attack attackContract;

    DAOWallet unsafeContract;
    SafeDAOWallet safeContract;

    function setUp() public virtual override {
        super.setUp();

        unsafeContract = new DAOWallet();
        safeContract = new SafeDAOWallet(dave, address(registry));
        _assignEscrowAsArchitect(address(safeContract));

        // Deposit ETH from non-cypher user into vulnerable contract
        vm.prank(alice);
        unsafeContract.deposit{value: 100}();

        // Deposit ETH into contract protected by Cypher
        vm.prank(bob);
        safeContract.deposit{value: 100}();
    }

    function testBalances() public {
        assertEq(address(unsafeContract).balance, 100);
        assertEq(address(safeContract).balance, 100);
    }

    function testAttackUnsafeContract() public {
        vm.startPrank(bob);
        uint256 balanceBefore = address(bob).balance;

        attackContract = new Attack(payable(address(unsafeContract)));
        attackContract.attack{value: 10}();
        assertEq(address(unsafeContract).balance, 0);
        assertEq(address(bob).balance, balanceBefore + 100);
        vm.stopPrank();
    }

    function testTransactionStoppedByEscrow() public {
        vm.startPrank(bob);

        assertEq(safeContract.balanceOf(bob), 100);
        safeContract.withdrawETH();

        bytes32 key = keccak256(abi.encodePacked(bob, address(safeContract), bob, uint256(0)));
        (, uint256 amount) = escrow.getTransaction(key);
        assertEq(amount, 100);

        vm.stopPrank();
    }

    function testTransactionStoppedByEscrowOracleAccepts() public {
        vm.startPrank(bob);

        assertEq(safeContract.balanceOf(bob), 100);
        safeContract.withdrawETH();

        bytes32 key = keccak256(abi.encodePacked(bob, address(safeContract), bob, uint256(0)));
        (, uint256 amount) = escrow.getTransaction(key);
        assertEq(amount, 100);

        vm.stopPrank();

        uint256 balanceBefore = address(bob).balance;

        vm.startPrank(carol);
        escrow.acceptTransaction(key);
        vm.stopPrank();

        assertEq(address(bob).balance, balanceBefore + 100);
    }

    function testTransactionStoppedByEscrowOracleDenies() public {
        vm.startPrank(bob);

        uint256 contractBalanceBefore = address(safeContract).balance;

        assertEq(safeContract.balanceOf(bob), 100);
        safeContract.withdrawETH();

        bytes32 key = keccak256(abi.encodePacked(bob, address(safeContract), bob, uint256(0)));
        (, uint256 amount) = escrow.getTransaction(key);
        assertEq(amount, 100);

        vm.stopPrank();

        uint256 balanceBefore = address(bob).balance;

        vm.startPrank(carol);
        escrow.denyTransaction(key, address(safeContract));
        vm.stopPrank();

        assertEq(address(bob).balance, balanceBefore);
        assertEq(address(safeContract).balance, contractBalanceBefore);
    }

    function testCannotAcceptTransactionStoppedByEscrowWhenNonOracle() public {
        vm.startPrank(bob);

        assertEq(safeContract.balanceOf(bob), 100);
        safeContract.withdrawETH();

        bytes32 key = keccak256(abi.encodePacked(bob, address(safeContract), bob, uint256(0)));
        (, uint256 amount) = escrow.getTransaction(key);
        assertEq(amount, 100);

        vm.stopPrank();

        uint256 balanceBefore = address(bob).balance;
        uint256 contractBalanceBefore = address(safeContract).balance;

        vm.startPrank(alice);
        vm.expectRevert(CypherEscrow.NotOracle.selector);
        escrow.acceptTransaction(key);
    }

    function testCannotDenyTransactionStoppedByEscrowWhenNonOracle() public {
        vm.startPrank(bob);

        assertEq(safeContract.balanceOf(bob), 100);
        safeContract.withdrawETH();

        bytes32 key = keccak256(abi.encodePacked(bob, address(safeContract), bob, uint256(0)));
        (, uint256 amount) = escrow.getTransaction(key);
        assertEq(amount, 100);

        vm.stopPrank();

        uint256 balanceBefore = address(bob).balance;
        uint256 contractBalanceBefore = address(safeContract).balance;

        vm.startPrank(alice);
        vm.expectRevert(CypherEscrow.NotOracle.selector);
        escrow.denyTransaction(key, alice);
    }

    function testWhitelistBypassesEscrow() public {
        vm.startPrank(carol);
        address[] memory whitelist = new address[](1);
        whitelist[0] = bob;
        escrow.addToWhitelist(whitelist);
        vm.stopPrank();

        vm.startPrank(bob);
        assertEq(safeContract.balanceOf(bob), 100);

        uint256 balanceBefore = address(bob).balance;
        safeContract.withdrawETH();

        assertEq(address(bob).balance, balanceBefore + 100);
        vm.stopPrank();
    }
}
