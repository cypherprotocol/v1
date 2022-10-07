// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";

contract CypherVaultERC20Test is BaseCypherTest {
    DAOWallet unsafeContract;
    SafeDAOWallet safeContract;

    function setUp() public virtual override {
        super.setUp();

        unsafeContract = new DAOWallet();
        safeContract = new SafeDAOWallet(dave, address(registry));

        _assignEscrowAsArchitect(address(safeContract));

        _grantApprovals(alice, address(unsafeContract));
        _grantApprovals(bob, address(safeContract));

        // Deposit ERC20 from non-cypher user into vulnerable contract
        vm.prank(alice);
        unsafeContract.depositTokens(address(token1), 100);

        // Deposit ERC20 into contract protected by Cypher
        vm.prank(bob);
        safeContract.depositTokens(address(token1), 100);
    }

    function testBalances() public {
        assertEq(token1.balanceOf(address(unsafeContract)), 100);
        assertEq(token1.balanceOf(address(safeContract)), 100);
    }

    // deposit ERC20 as collateral (can be USDC), get ETH back
    // function testDrainRariWithERC20Collateral() public {
    //     vm.startPrank(bob);

    //     token1.transfer(address(attackTokenContract), 1 ether);

    //     // // attack the contract by:
    //     // // 1. depositing tokens
    //     // // 2. reentering on the borrow

    //     uint256 balanceBefore = address(bob).balance;
    //     attackTokenContract.attackRari(1 ether);
    //     assertEq(address(bob).balance, balanceBefore + 100 ether);

    //     emit log(unicode"✅ Deployed test token contracts");

    //     vm.stopPrank();
    // }
}
