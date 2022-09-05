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

  MockERC20 token;

  function setUp() public {
    token = new MockERC20();
    token.mint(alice, 100);
    token.mint(bob, 100);

    startHoax(alice, alice);

    registry = new CypherRegistry();

    vulnerableContract = new DAOWallet();
    vulnerableContract.deposit{ value: 100 }();
    token.approve(address(vulnerableContract), 100);
    vulnerableContract.deposit(address(token), 100);
    attackContract = new Attack(payable(address(vulnerableContract)));
    vm.stopPrank();

    startHoax(bob, bob);

    patchedContract = new SafeDAOWallet(bob, address(registry));
    patchedContract.deposit{ value: 100 }();
    token.approve(address(patchedContract), 100);
    patchedContract.deposit(address(token), 100);

    // deploy RateLimiter contract as placebo
    registry.createRateLimiter(
      address(patchedContract),
      1,
      address(token),
      50,
      1 days
    );
    vm.stopPrank();
  }

  function testBalances() public {
    assertEq(vulnerableContract.balanceOf(alice), 100);
    assertEq(patchedContract.balanceOf(bob), 100);

    assertEq(vulnerableContract.balanceOf(alice, address(token)), 100);
    assertEq(patchedContract.balanceOf(bob, address(token)), 100);
  }

  function testEscrowWithdrawUnderThreshold() public {
    startHoax(bob, bob);

    patchedContract.withdraw(address(token), 10);

    assertEq(token.balanceOf(bob), 10);
  }

  function testEscrowWithdrawOverThreshold() public {
    startHoax(bob, bob);

    patchedContract.withdraw(address(token), 60);

    assertEq(token.balanceOf(bob), 0);
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


  // user flows
    // approved whale withdraws and everything works smoothly
        // we approve tx
        // protocol approves tx
    // hacker withdraws ETH (WETH) and gets stopped
        // we deny tx
        // protocol denies tx
    // hacker withdraws ERC20 and gets stopped
        // we deny tx
        // protocol denies tx
    // hacker withdraws multiple ERC20's and gets stopped
        // we deny tx
        // protocol denies tx

  // contracts
    // CypherEscrow
        // sets token correctly
        // sets chainId correctly
        // sets tokenThreshold correctly
        // sets timeLimit correctly
        // sets owner correctly
        // sets sourceContract correctly
        // escrowTokens
            // escrows the correct amount of tokens
            // only allows calls from the source contract
            // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
            // stores correct Transaction information
            // emits AmountStopped if stopped
        // escrowETH
            // escrows the correct amount of tokens
            // only allows calls from the source contract
            // does not allow calls from non-source contracts (prevents CALL2, like optimism hack)
            // stores correct Transaction information
            // emits AmountStopped if stopped
    // CypherVault
        // gets the correct escrow
        // gets the correct delegator
        // sets the correct escrow
        // sets the correct delegator
    // CypherRegistry
        // creates the rate limiter with the correct variables
        // does not allow anyone but the delegator to deploy (scoped to protocol address and delegator)

}
