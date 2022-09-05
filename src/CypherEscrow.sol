// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";

/// @author bmwoolf and zksoju
/// @title Rate limiter for smart contract withdrawals- much like the bank's rate limiter
/// @notice Assumes the incoming asset is already wrapped from a token pool
contract CypherEscrow {
  address public sourceContract;
  address public owner;

  address public token;

  uint256 public chainId;
  uint256 public tokenThreshold;
  uint256 public timeLimit;
  uint256 public timePeriod;

  /// @notice Whales that are whitelisted to withdraw without rate limiting
  mapping(address => bool) public whitelist;
  /// @notice Request info mapping
  mapping(address => Transaction) public tokenInfo;

  /// @notice Withdraw request info
  struct Transaction {
    address asset;
    uint256 amount;
    uint256 assetChainId;
    bool approved;
    bool initialized;
  }

  event AmountSent(address to, uint256 amount, uint256 timestamp);
  event AmountStopped(
    address to,
    address tokenContract,
    uint256 amount,
    uint256 timestamp
  );

  modifier onlySourceContractOwner() {
    require(msg.sender == owner);
    _;
  }

  constructor(
    address _sourceContract,
    uint256 _chainId,
    address _token,
    uint256 _tokenThreshold,
    uint256 _timeLimit,
    address _owner
  ) {
    token = _token;
    chainId = _chainId;
    tokenThreshold = _tokenThreshold;
    timeLimit = _timeLimit;
    owner = _owner;
    sourceContract = _sourceContract;
  }

  /// @notice Check if an ERC20 withdraw is valid
  /// @param to The address to withdraw to
  /// @param asset The ERC20 token contract to withdraw from
  /// @param amount The amount to withdraw
  /// @param chainId_ The chain id of the token contract
  function escrowTokens(
    address to,
    address asset,
    uint256 amount,
    uint256 chainId_
  ) external {
    // check if the stop has been overwritten by protocol owner on the frontend
    require(msg.sender == sourceContract, "ONLY_SOURCE_CONTRACT");
    require(chainId == chainId_, "CHAIN_ID_MISMATCH");

    // if they are whitelisted or amount is less than threshold, just transfer the tokens
    if (amount < tokenThreshold || whitelist[msg.sender] == true) {
      bool result = IERC20(asset).transferFrom(sourceContract, to, amount);
      require(result, "TRANSFER_FAILED");
    } else if (tokenInfo[msg.sender].initialized == false) {
      // if they havent been cached
      // add them to the cache
      addToLimiter(to, asset, amount, chainId_);

      emit AmountStopped(to, asset, amount, block.timestamp);
    } else {
      // check if they have been approved
      require(tokenInfo[msg.sender].approved == true, "NOT_APPROVED");

      // if so, allow them to withdraw the full amount
      bool result = IERC20(asset).transferFrom(asset, to, amount);
      require(result, "TRANSFER_FAILED");
    }
  }

  /// @notice Add a user to the limiter
  /// @param _to The address to add to the limiter
  /// @param _tokenContract The ERC20 token contract to add to the limiter (ETH is 0x00..00)
  /// @param _amount The amount to add to the limiter
  /// @param chainId_ The chain id of the token contract
  function addToLimiter(
    address _to,
    address _tokenContract,
    uint256 _amount,
    uint256 chainId_
  ) private {
    tokenInfo[_to].asset = _tokenContract;
    tokenInfo[_to].assetChainId = chainId_;
    tokenInfo[_to].amount = _amount;
    tokenInfo[_to].approved = false;
    tokenInfo[_to].initialized = true;
  }

  /// @notice Send approved funds to a user
  /// @param to The address to send to
  /// @param tokenContract The contract address of the token to send
  function releaseTokens(address to, address tokenContract)
    external
    onlySourceContractOwner
    nonReentrant
  {
    require(tokenInfo[to].approved = true, "NOT_APPROVED");
    uint256 amount = tokenInfo[to].amount;

    tokenInfo[to].amount -= amount;

    // our contract needs approval to swap tokens
    bool result = IERC20(tokenContract).transferFrom(tokenContract, to, amount);
    require(result == true, "TRANSFER_FAILED");

    emit AmountSent(to, amount, block.timestamp);
  }

  /// @notice Set the timelimit for the tx before reverting
  /// @param _timeLimit The time limit in seconds
  function setTimeLimit(uint256 _timeLimit) external onlySourceContractOwner {
    timeLimit = _timeLimit;
  }

  /// @notice Add an address to the whitelist
  /// @param to The address to add to the whitelist
  function addToWhitelist(address[] memory to)
    external
    onlySourceContractOwner
  {
    for (uint256 i = 0; i < to.length; i++) {
      whitelist[to[i]] = true;
    }
  }

  /// @notice Approve a withdraw to a user
  /// @param to The address to approve to
  function approveWithdraw(address to) external onlySourceContractOwner {
    tokenInfo[to].approved = true;
  }
}
