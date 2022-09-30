// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {CypherEscrow} from "../src/CypherEscrow.sol";
import {AttackToken} from "./exploits/ERC20Reentrancy/Attack.sol";
import {AttackSafeToken} from "./exploits/ERC20Reentrancy/AttackSafe.sol";
import {DAOWallet} from "./exploits/ERC20Reentrancy/DAOWallet.sol";
import {SafeDAOWallet} from "./exploits/SafeDAOWallet.sol";
import {CypherRegistry} from "../src/CypherRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockRari} from "./exploits/attacks/rari/MockRari.sol";
import {SafeMockRari} from "./exploits/attacks/rari/SafeMockRari.sol";
import {Bool} from "./lib/BoolTool.sol";

contract CypherVaultERC20Test is Test {
    AttackToken attackTokenContract;
    DAOWallet vulnerableContract;
    CypherEscrow escrow;
    CypherRegistry registry;
    MockERC20 token;
    MockRari mockRari;
    SafeMockRari safeMockRari;

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
        safeMockRari = new SafeMockRari(address(token), architect, address(registry));
        token.approve(address(safeMockRari), 100);
        safeMockRari.depositTokens(100);


        address[] memory oracles = new address[](2);
        oracles[0] = architect;
        oracles[1] = cypher;

        // Deploy escrow contract from designated architect
        escrow = CypherEscrow(registry.createEscrow(address(safeMockRari), 1, address(token), 50, 1 days, oracles));

        address[] memory whales = new address[](1);
        whales[0] = whale;

        escrow.addToWhitelist(whales);
        vm.stopPrank();

        startHoax(whale, whale);
        // safeMockRari.depositTokens(100);
        token.approve(address(safeMockRari), 100);
        safeMockRari.depositTokens(100); // now at 200
        vm.stopPrank();

        // deploy mockk Rari contracts with eth (to mimic a pool)
        mockRari = new MockRari(address(token));
        // send eth to mock Rari contract
        address(mockRari).call{value: 100 ether}("");
        assertEq(address(mockRari).balance, 100 ether);
        // send eth to safe mock Rari contract
        address(safeMockRari).call{value: 100 ether}("");
        assertEq(address(safeMockRari).balance, 100 ether);
    }

    function testBalances() public {
        assertEq(token.balanceOf(address(vulnerableContract)), 100);
        assertEq(token.balanceOf(address(safeMockRari)), 200);
    }

    // deposit ERC20 as collateral (can be USDC), get ETH back
    function testHackToken() public {
        assertEq(address(mockRari).balance, 100 ether);
        startHoax(hacker, 1 ether);
        assertEq(hacker.balance, 1 ether);

        attackTokenContract = new AttackToken(address(token), payable(address(mockRari)));

        uint256 deposit = 1 ether;
        // mint here since setUp is not working
        token.mint(address(attackTokenContract), 1 ether);
        assertEq(token.balanceOf(address(attackTokenContract)), 1 ether);

        // attack the contract by:
        // 1. depositing tokens
        // 2. reentering on the borrow
        attackTokenContract.attackRari(deposit);
        assertEq(address(hacker).balance, 101 ether);
        vm.stopPrank();
    }

    function testCypher() public {
      assertEq(address(mockRari).balance, 100 ether);
        startHoax(hacker, 1 ether);
        assertEq(hacker.balance, 1 ether);

        attackTokenContract = new AttackToken(address(token), payable(address(safeMockRari)));
        // rust stack times out if we do gwei
        uint256 deposit = 1 ether;
        // mint here since setUp is not working
        token.mint(address(attackTokenContract), 1 ether);
        assertEq(token.balanceOf(address(attackTokenContract)), 1 ether);
        attackTokenContract.attackRari(deposit);
        assertEq(hacker.balance, 1 ether);
        vm.stopPrank();
    }
}
