// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

error NotOracle();
error NotSourceContract();
error NotApproved();
error MustBeDisapproved();
error ChainIdMismatch();
error TransferFailed();

/// @author bmwoolf and zksoju
/// @title Rate limiter for smart contract withdrawals- much like the bank's rate limiter
contract CypherEscrow is ReentrancyGuard {
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
        address origin;
        address asset;
        uint256 amount;
        uint256 assetChainId;
        bool approved;
        bool initialized;
    }

    event AmountSent(address indexed from, address indexed to, address tokenContract, uint256 amount);
    event AmountStopped(address indexed from, address indexed to, address tokenContract, uint256 amount);
    event TransactionDenied(address indexed to, address tokenContract, uint256 amount);
    event OracleAdded(address indexed user, address oracle);
    event TimeLimitSet(uint256 timeLimit);
    event AddressAddedToWhitelist(address indexed user, address whitelist);
    event WithdrawApproved(address indexed user, address indexed to);
    event WithdrawDisapproved(address indexed user, address indexed to);

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

        Transaction memory txInfo = tokenInfo[to];

        uint256 amount = msg.value;

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[from] == true) {
            (bool success, ) = address(to).call{value: amount}("");

            if (!success) revert TransferFailed();
        } else if (txInfo.initialized == false) {
            // if they havent been cached, add them to the cache
            // addToLimiter(to, sourceContract, amount, chainId_);
            addToLimiter(msg.sender, to, address(0x0), amount, chainId_);
        } else {
            // check if they have been approved
            if (txInfo.approved != true) revert NotApproved();

            // if so, allow them to withdraw the full amount
            (bool success, ) = address(to).call{value: amount}("");
            if (!success) revert TransferFailed();

            emit AmountSent(from, to, address(0x0), amount);
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
            addToLimiter(from, to, asset, amount, chainId_);
        } else {
            // check if they have been approved
            if (tokenInfo[msg.sender].approved != true) revert NotApproved();

            // if so, allow them to withdraw the full amount
            bool result = IERC20(asset).transferFrom(asset, to, amount);
            if (!result) revert TransferFailed();

            emit AmountSent(from, to, asset, amount);
        }
    }

    /// @notice Add a user to the limiter
    /// @param _to The address to add to the limiter
    /// @param _tokenContract The ERC20 token contract to add to the limiter (ETH is 0x00..00)
    /// @param _amount The amount to add to the limiter
    /// @param chainId_ The chain id of the token contract
    function addToLimiter(
        address _from,
        address _to,
        address _tokenContract,
        uint256 _amount,
        uint256 chainId_
    ) internal {
        tokenInfo[_to].origin = _from;
        tokenInfo[_to].asset = _tokenContract;
        tokenInfo[_to].assetChainId = chainId_;
        tokenInfo[_to].amount = _amount;
        tokenInfo[_to].approved = false;
        tokenInfo[_to].initialized = true;

        emit AmountStopped(_from, _to, _tokenContract, _amount);
    }

    /// @notice Send approved funds to a user
    /// @param to The address to send to
    /// @param tokenContract The contract address of the token to send
    function releaseTokens(address to, address tokenContract) external onlyOracle nonReentrant {
        Transaction memory txInfo = tokenInfo[to];

        if (txInfo.approved != true) revert NotApproved();
        uint256 amount = txInfo.amount;

        txInfo.amount -= amount;

        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(to).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(tokenContract).transferFrom(tokenContract, to, amount);
            if (!result) revert TransferFailed();
        }

        emit AmountSent(txInfo.origin, to, tokenContract, amount);
    }

    /// @notice Sends the funds back to the protocol- needs to be after they have fixed the exploit
    /// @param to the funds back to the protocol- needs to be after they have fixed the exploit
    function denyTransaction(address to) external onlyOracle nonReentrant {
        Transaction memory txInfo = tokenInfo[to];

        // need the to to be disapproved
        if (txInfo.approved == true) revert MustBeDisapproved();

        // Send ETH back
        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(sourceContract).call{value: txInfo.amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Send ERC20 back
            /// TODO: this could be a potential exploit
            address token = txInfo.asset;
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(token).transferFrom(to, token, txInfo.amount);
        }

        emit TransactionDenied(to, txInfo.asset, txInfo.amount);
    }

    /// @notice Set the timelimit for the tx before reverting
    /// @param _timeLimit The time limit in seconds
    function setTimeLimit(uint256 _timeLimit) external onlyOracle {
        timeLimit = _timeLimit;

        emit TimeLimitSet(timeLimit);
    }

    /// @notice Add an address to the whitelist
    /// @param to The address to add to the whitelist
    function addToWhitelist(address[] memory to) external onlyOracle {
        for (uint256 i = 0; i < to.length; i++) {
            isWhitelisted[to[i]] = true;

            emit AddressAddedToWhitelist(msg.sender, to[i]);
        }
    }

    /// @notice Approve a withdraw to a user
    /// @param to The address to approve to
    function approveWithdraw(address to) external onlyOracle {
        tokenInfo[to].approved = true;

        emit WithdrawApproved(msg.sender, to);
    }

    /// @notice Disapprove a withdraw to a user
    /// @param to The address to disapprove
    function disapproveWithdraw(address to) external onlyOracle {
        tokenInfo[to].approved = false;

        emit WithdrawDisapproved(msg.sender, to);
    }

    /// @dev Add a new oracle
    /// @param _oracle The address of the new oracle
    /// @notice Can only come from a current oracle
    function addOracle(address _oracle) external onlyOracle {
        isOracle[_oracle] = true;

        emit OracleAdded(msg.sender, _oracle);
    }

    /// @dev Get wallet balance for specific wallet
    /// @param to Wallet to query balance for
    /// @return Token amount
    function getWalletBalance(address to) external returns (uint256) {
        return tokenInfo[to].amount;
    }

    /// @dev Get approval status for specific wallet
    /// @param to Wallet to query approval for
    /// @return Token amount
    function getApprovalStatus(address to) external returns (bool) {
        return tokenInfo[to].approved;
    }
}
