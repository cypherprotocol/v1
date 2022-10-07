// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {Attack} from "./exploits/ETHReentrancy/Attack.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {CypherEscrow} from "../src/CypherEscrow.sol";

contract CypherEscrowRegistryTest is BaseCypherTest {
    function testRegistry() public {
        BaseCypherTest._deployContracts();
        BaseCypherTest._deployTestContracts();
        // need to attach an escrow to the registry
    }
}