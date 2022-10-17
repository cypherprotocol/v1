// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {BaseCypherTest} from "./utils/BaseCypherTest.sol";

import {Attack} from "./exploits/ETHReentrancy/Attack.sol";
import {DAOWallet} from "./mocks/DAOWallet.sol";
import {SafeDAOWallet} from "./mocks/SafeDAOWallet.sol";
import {CypherEscrow} from "../src/CypherEscrow.sol";
import {CypherRegistry} from "../src/CypherRegistry.sol";
import {MockProtocol} from "./mocks/MockProtocol.sol";

contract CypherEscrowRegistryTest is BaseCypherTest {
    function setUp() public virtual override {
        // override to prevent registry creation
        registry = new CypherRegistry();
        protocol = new MockProtocol(dave, address(registry));
    }

    function testRegistry() public {
        // BaseCypherTest._deployContracts();
        // BaseCypherTest._deployTestContracts();
        // need to attach an escrow to the registry
    }

    function testCannotCreateEscrowWhenProtocolAlreadyRegistered() public {
        vm.startPrank(dave);
        registry.createEscrow(address(protocol), address(token1), THRESHOLD, EXPIRY_DURATION, verifiers);

        vm.expectRevert(CypherRegistry.ProtocolAlreadyRegistered.selector);
        registry.createEscrow(address(protocol), address(token1), THRESHOLD, EXPIRY_DURATION, verifiers);
        vm.stopPrank();
    }
}
