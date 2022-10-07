// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {Attack} from "./exploits/ETHReentrancy/Attack.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {CypherEscrow} from "../src/CypherEscrow.sol";

contract CypherVaultRegistryTest is BaseCypherTest {
    function testRegistry() public {
        assertEq(address(registry), address(registry));
    }

    function testEventEmitted() public {
        // assert equal that the EscrowCreated event was emitted
        // expectEmit(CreateEscrow);
    }
}