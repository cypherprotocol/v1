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

  address alice = address(0xBEEF);
  address bob = address(0xDEAD);

  MockERC20 USDC;

  function setUp() public {
    USDC = new MockERC20();
    USDC.mint(alice, 100);
    USDC.mint(bob, 100);

    startHoax(alice, alice);

    registry = new CypherRegistry();


    // deploy Reentrance contract
    vulnerableContract = new DAOWallet();
    vulnerableContract.deposit{ value: 100 }();
    attackContract = new Attack(payable(address(vulnerableContract)));
    vm.stopPrank();

    startHoax(bob, bob);

    patchedContract = new SafeDAOWallet(bob, address(registry));
    USDC.approve(address(patchedContract), 100);
    patchedContract.deposit(address(USDC), 100);

    // deploy RateLimiter contract as placebo
    registry.createRateLimiter(
      address(patchedContract),
      1,
      address(USDC),
      50,
      1 days
    );
    vm.stopPrank();
  }

  function testBalances() public {
    assertEq(vulnerableContract.balanceOf(alice), 100);
    assertEq(patchedContract.balanceOf(bob), 100);
  }

  function testEscrowWithdrawUnderThreshold() public {
    startHoax(bob, bob);

    patchedContract.withdraw(address(USDC), 10);

    assertEq(USDC.balanceOf(bob), 10);
  }

  function testEscrowWithdrawOverThreshold() public {
    startHoax(bob, bob);

    patchedContract.withdraw(address(USDC), 60);

    assertEq(USDC.balanceOf(bob), 0);
  }

//   function testAttackOnVulnerableContract() public {
//     // send ETH to Attack contract so it can execute reentrancy attack
//     sendAttackContractETH.call{value: 100}();

//     // get contract balances before attack
//     uint256 vulnerableContractBalanceBefore = vulnerableContract.balanceOf(
//       alice
//     );
//     assertEq(vulnerableContractBalanceBefore, 100);

//     // get contract balance
//     uint256 contractBalanceBeforeHack = vulnerableContract.balanceOf(
//       address(attackContract)
//     );
//     assertEq(contractBalanceBeforeHack, 0);

//     attackContract.step1_causeOverflow();
//     attackContract.step2_deplete();

//     // assert that the balance of the contract is 0
//     assertEq(vulnerableContract.balanceOf(address(attackContract)), 0);

//     // assert that the balance of the wallet is the same as the balance of the contract before being drained
//     assertEq(patchedContract.balanceOf(address(cypherEscrow)), 100);
//   }

//   function testAttackOnPatchContract() public {}

  /// @notice Utility function
  function sendAttackContractETH() public payable {
    emit log_named_uint("sendAttackContractETH", msg.value);
    (bool sent, ) = address(attackContract).call{ value: msg.value }("");
    require(sent, "Failed to send Ether");
  }
}
