// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {AttackToken} from "./exploits/ERC20Reentrancy/Attack.sol";
import {AttackSafeToken} from "./exploits/ERC20Reentrancy/AttackSafe.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {MockRari} from "./exploits/attacks/rari/MockRari.sol";
import {SafeMockRari} from "./exploits/attacks/rari/SafeMockRari.sol";

contract CypherVaultERC20Test is BaseCypherTest {
    AttackToken attackTokenContract;
    DAOWallet vulnerableContract;

    MockRari mockRari;
    SafeMockRari safeMockRari;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(carol);
        vulnerableContract = new DAOWallet();

        _grantApprovals(alice, address(vulnerableContract));

        // Deposit ERC20 into non-Cypher, vulnerable contract
        vm.startPrank(alice);
        vulnerableContract.depositTokens(address(token1), 100);
        vm.stopPrank();

        safeMockRari = new SafeMockRari(address(token1), dave, address(registry));

        _assignEscrowAsArchitect(address(safeMockRari));
        _grantApprovals(bob, address(safeMockRari));

        // Deposit ERC20 into contract protected by Cypher
        vm.startPrank(bob);
        safeMockRari.depositTokens(100);

        // address[] memory whales = new address[](1);
        // whales[0] = whale;

        // escrow.addToWhitelist(whales);
        // vm.stopPrank();

        // startHoax(whale, whale);
        // // safeMockRari.depositTokens(100);
        // token.approve(address(safeMockRari), 100);
        // safeMockRari.depositTokens(100); // now at 200
        // vm.stopPrank();

        // deploy mockk Rari contracts with eth (to mimic a pool)
        mockRari = new MockRari(address(token1));
        attackTokenContract = new AttackToken(address(token1), payable(address(mockRari)));
        vm.stopPrank();

        _supplyAdditionalBalance();
    }

    function _supplyAdditionalBalance() internal {
        _grantApprovals(carol, address(safeMockRari));
        _grantApprovals(carol, address(mockRari));

        vm.startPrank(carol);

        mockRari.depositTokens(100);
        safeMockRari.depositTokens(100);

        address(mockRari).call{value: 100 ether}("");
        assertEq(address(mockRari).balance, 100 ether);
        // send eth to safe mock Rari contract
        address(safeMockRari).call{value: 100 ether}("");
        assertEq(address(safeMockRari).balance, 100 ether);

        vm.stopPrank();
    }

    function testBalances() public {
        assertEq(token1.balanceOf(address(vulnerableContract)), 100);
        assertEq(token1.balanceOf(address(safeMockRari)), 200);
    }

    // deposit ERC20 as collateral (can be USDC), get ETH back
    function testDrainRariWithERC20Collateral() public {
        vm.startPrank(bob);

        token1.transfer(address(attackTokenContract), 1 ether);

        // // attack the contract by:
        // // 1. depositing tokens
        // // 2. reentering on the borrow

        uint256 balanceBefore = address(bob).balance;
        attackTokenContract.attackRari(1 ether);
        assertEq(address(bob).balance, balanceBefore + 100 ether);

        emit log(unicode"✅ Deployed test token contracts");

        vm.stopPrank();
    }

    // function testCypher() public {
    //     assertEq(address(mockRari).balance, 100 ether);
    //     startHoax(hacker, 1 ether);
    //     assertEq(hacker.balance, 1 ether);

    //     attackTokenContract = new AttackToken(address(token), payable(address(safeMockRari)));
    //     // rust stack times out if we do gwei
    //     uint256 deposit = 1 ether;
    //     // mint here since setUp is not working
    //     token.mint(address(attackTokenContract), 1 ether);
    //     assertEq(token.balanceOf(address(attackTokenContract)), 1 ether);
    //     attackTokenContract.attackRari(deposit);
    //     assertEq(hacker.balance, 1 ether);
    //     vm.stopPrank();
    // }
}
