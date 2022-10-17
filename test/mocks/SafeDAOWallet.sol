// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ICypherEscrow} from "../../src/interfaces/ICypherEscrow.sol";
import {CypherProtocol} from "../../src/CypherProtocol.sol";

import "forge-std/Test.sol";

contract SafeDAOWallet is CypherProtocol, Test {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public ethBalances;

    constructor(address deployer, address registry) CypherProtocol("DAOWallet", deployer, registry) {}

    function deposit() public payable {
        ethBalances[msg.sender] += (msg.value);
    }

    function depositTokens(address token, uint256 amount) public {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return ethBalances[_who];
    }

    function balanceOf(address _who, address _token) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdrawETH() public {
        require(ethBalances[msg.sender] >= 0, "INSUFFICIENT_FUNDS");

        ICypherEscrow escrow = ICypherEscrow(getEscrow());
        escrow.escrowETH{value: ethBalances[msg.sender]}(msg.sender, msg.sender);

        ethBalances[msg.sender] = 0;
    }

    function withdraw(address token, uint256 _amount) public {
        // if the user has enough balance to withdraw
        require(balances[msg.sender] >= _amount, "INSUFFICIENT_FUNDS");

        ICypherEscrow escrow = ICypherEscrow(getEscrow());
        ERC20(token).approve(address(escrow), _amount);
        escrow.escrowTokens(address(this), msg.sender, token, _amount);

        balances[msg.sender] -= _amount;
    }

    function getContractBalance() public returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
