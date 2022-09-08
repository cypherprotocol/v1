// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";

import "forge-std/Test.sol";

error NotOracle();
error NotSourceContract();
error NotApproved();
error ChainIdMismatch();
error TransferFailed();

/// @author bmwoolf and zksoju
/// @title Rate limiter for smart contract withdrawals- much like the bank's rate limiter
contract CypherEscrow is ReentrancyGuard, Test {
  address public sourceContract;

  mapping(address => bool) isOracle;

  address public token;

  uint256 public chainId;
  uint256 public tokenThreshold;
  uint256 public timeLimit;
  uint256 public timePeriod;

  /// @notice Whales that are whitelisted to withdraw without rate limiting
  mapping(address => bool) public isWhitelisted;
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

  event AmountSent(
    address to,
    address tokenContract,
    uint256 amount,
    uint256 timestamp
  );
  event AmountStopped(
    address to,
    address tokenContract,
    uint256 amount,
    uint256 timestamp
  );
  event OracleAdded(address newOracle, address oracleThatAdded);

  modifier onlyOracle() {
    bool isAuthorized = isOracle[msg.sender];
    if (!isAuthorized) revert NotOracle();
    _;
  }

  constructor(
    address _sourceContract,
    uint256 _chainId,
    address _token,
    uint256 _tokenThreshold,
    uint256 _timeLimit,
    address[] memory _oracles
  ) {
    token = _token;
    chainId = _chainId;
    tokenThreshold = _tokenThreshold;
    timeLimit = _timeLimit;
    sourceContract = _sourceContract;

    for (uint256 i = 0; i < _oracles.length; i++) {
      isOracle[_oracles[i]] = true;
    }
  }

  /// @notice Check if an ETH withdraw is valid
  /// @param to The address to withdraw to
  /// @param chainId_ The chain id of the token contract
  function escrowETH(
    address from,
    address to,
    uint256 chainId_
  ) external payable nonReentrant {
    // check if the stop has been overwritten by protocol owner on the frontend
    if (msg.sender != sourceContract) revert NotSourceContract();
    if (chainId != chainId_) revert ChainIdMismatch();

    uint256 amount = msg.value;

    // if they are whitelisted or amount is less than threshold, just transfer the tokens
    if (amount < tokenThreshold || isWhitelisted[from] == true) {
      (bool success, ) = address(to).call{ value: amount }("");
      if (!success) revert TransferFailed();
    } else if (tokenInfo[to].initialized == false) {
      // if they havent been cached, add them to the cache
      // addToLimiter(to, sourceContract, amount, chainId_);
      addToLimiter(to, address(0x0), amount, chainId_);
    } else {
      // check if they have been approved
      if (tokenInfo[to].approved != true) revert NotApproved();

      // if so, allow them to withdraw the full amount
      (bool success, ) = address(to).call{ value: amount }("");
      if (!success) revert TransferFailed();

      emit AmountSent(to, address(0x0), amount, block.timestamp);
    }
  }

  /// @notice Check if an ERC20 withdraw is valid
  /// @param to The address to withdraw to
  /// @param asset The ERC20 token contract to withdraw from
  /// @param amount The amount to withdraw
  /// @param chainId_ The chain id of the token contract
  function escrowTokens(
    address from,
    address to,
    address asset,
    uint256 amount,
    uint256 chainId_
  ) external {
    // check if the stop has been overwritten by protocol owner on the frontend
    if (msg.sender != sourceContract) revert NotSourceContract();
    if (chainId != chainId_) revert ChainIdMismatch();

    // if they are whitelisted or amount is less than threshold, just transfer the tokens
    if (amount < tokenThreshold || isWhitelisted[from] == true) {
      bool result = IERC20(asset).transferFrom(sourceContract, to, amount);
      if (!result) revert TransferFailed();
    } else if (tokenInfo[to].initialized == false) {
      // if they havent been cached
      // add them to the cache
      addToLimiter(to, asset, amount, chainId_);
    } else {
      // check if they have been approved
      if (tokenInfo[msg.sender].approved != true) revert NotApproved();

      // if so, allow them to withdraw the full amount
      bool result = IERC20(asset).transferFrom(asset, to, amount);
      if (!result) revert TransferFailed();

      emit AmountSent(to, asset, amount, block.timestamp);
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

    emit AmountStopped(_to, _tokenContract, _amount, block.timestamp);
  }

  /// @notice Send approved funds to a user
  /// @param to The address to send to
  /// @param tokenContract The contract address of the token to send
  function releaseTokens(address to, address tokenContract)
    external
    onlyOracle
    nonReentrant
  {
    if (tokenInfo[to].approved != true) revert NotApproved();
    uint256 amount = tokenInfo[to].amount;

    tokenInfo[to].amount -= amount;

    if (tokenInfo[to].asset == address(0x0)) {
      (bool success, ) = address(to).call{ value: amount }("");
      if (!success) revert TransferFailed();

      emit AmountSent(to, address(0x0), amount, block.timestamp);
    } else {
      // our contract needs approval to swap tokens
      bool result = IERC20(tokenContract).transferFrom(
        tokenContract,
        to,
        amount
      );
      if (!result) revert TransferFailed();

      emit AmountSent(to, asset, amount, block.timestamp);
    }

    emit AmountSent(to, amount, block.timestamp);
  }

  /// @notice Set the timelimit for the tx before reverting
  /// @param _timeLimit The time limit in seconds
  function setTimeLimit(uint256 _timeLimit) external onlyOracle {
    timeLimit = _timeLimit;
  }

  /// @notice Add an address to the whitelist
  /// @param to The address to add to the whitelist
  function addToWhitelist(address[] memory to) external onlyOracle {
    for (uint256 i = 0; i < to.length; i++) {
      isWhitelisted[to[i]] = true;
    }
  }

  /// @notice Approve a withdraw to a user
  /// @param to The address to approve to
  function approveWithdraw(address to) external onlyOracle {
    tokenInfo[to].approved = true;
  }

  /// @dev Add a new oracle
  /// @param _oracle The address of the new oracle
  /// @notice Can only come from a current oracle
  function addOracle(address _oracle) external onlyOracle {
    isOracle[_oracle] = true;

    emit OracleAdded(_oracle, msg.sender);
  }

  /// @dev Get wallet balance for specific wallet
  /// @param wallet Wallet to query balance for
  /// @return Token amount
  function getWalletBalance(address wallet) external returns (uint256) {
    return tokenInfo[wallet].amount;
  }
}
