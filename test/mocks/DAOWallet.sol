// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "forge-std/Test.sol";

contract DAOWallet is Test {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public ethBalances;

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

        (bool result, ) = msg.sender.call{value: ethBalances[msg.sender]}("");
        require(result, "WITHDRAW_FAILED");

        // this is the attack- decrement AFTER withdraw (should be before)
        ethBalances[msg.sender] = 0;
    }

    function withdraw(address token, uint256 _amount) public {
        // if the user has enough balance to withdraw
        require(balances[msg.sender] >= _amount, "INSUFFICIENT_FUNDS");

        ERC20(token).transferFrom(address(this), msg.sender, _amount);
        balances[msg.sender] -= _amount;
    }

    receive() external payable {}
}
