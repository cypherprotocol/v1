// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

error NotOracle();
error NotSourceContract();
error NotApproved();
error MustBeDisapproved();
error TransferFailed();

/// @author bmwoolf and zksoju
/// @title Rate limiter for smart contract withdrawals- much like the bank's rate limiter
contract CypherEscrow is ReentrancyGuard {
    address public sourceContract;

    mapping(address => bool) isOracle;

    address public token;

    uint256 public tokenThreshold;
    uint256 public timeLimit;
    uint256 public timePeriod;

    /// @notice Whales that are whitelisted to withdraw without rate limiting
    mapping(address => bool) public isWhitelisted;
    /// @notice Request info mapping
    mapping(bytes32 => Transaction) public tokenInfo;

    /// @notice Withdraw request info
    struct Transaction {
        address origin;
        address destination;
        address asset;
        uint256 amount;
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
        address _token,
        uint256 _tokenThreshold,
        uint256 _timeLimit,
        address[] memory _oracles
    ) {
        token = _token;
        tokenThreshold = _tokenThreshold;
        timeLimit = _timeLimit;
        sourceContract = _sourceContract;

        for (uint256 i = 0; i < _oracles.length; i++) {
            isOracle[_oracles[i]] = true;
        }
    }

    /// @notice Check if an ETH withdraw is valid
    /// @param to The address to withdraw to
    function escrowETH(address from, address to) external payable nonReentrant {
        // check if the stop has been overwritten by protocol owner on the frontend
        if (msg.sender != sourceContract) revert NotSourceContract();

        // create key hash for tokenInfo mapping
        bytes32 key = hashTransactionKey(from, to, address(0), amount);

        Transaction memory txInfo = tokenInfo[key];

        uint256 amount = msg.value;

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[from] == true) {
            (bool success, ) = address(to).call{value: amount}("");

            if (!success) revert TransferFailed();
        } else if (txInfo.initialized == false) {
            // if they havent been cached, add them to the cache
            // addToLimiter(to, sourceContract, amount, chainId_);
            addToLimiter(key, msg.sender, to, address(0x0), amount);
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
    function escrowTokens(
        address from,
        address to,
        address asset,
        uint256 amount
    ) external {
        // check if the stop has been overwritten by protocol owner on the frontend
        if (msg.sender != sourceContract) revert NotSourceContract();

        // create key hash for tokenInfo mapping
        bytes32 key = hashTransactionKey(from, to, asset, amount);

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[from] == true) {
            bool result = IERC20(asset).transferFrom(sourceContract, to, amount);
            if (!result) revert TransferFailed();
        } else if (tokenInfo[key].initialized == false) {
            // if they havent been cached
            // add them to the cache
            addToLimiter(key, from, to, asset, amount);
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
    /// @param key The key to check the Transaction struct info
    /// @param _from The address from to add to the limiter
    /// @param _to The address to add to the limiter
    /// @param _tokenContract The ERC20 token contract to add to the limiter (ETH is 0x00..00)
    /// @param _amount The amount to add to the limiter
    function addToLimiter(
        bytes32 key,
        address _from,
        address _to,
        address _tokenContract,
        uint256 _amount
    ) internal {
        tokenInfo[key].origin = _from;
        tokenInfo[key].destination = _to;
        tokenInfo[key].asset = _tokenContract;
        tokenInfo[key].amount = _amount;
        tokenInfo[key].approved = false;
        tokenInfo[key].initialized = true;

        emit AmountStopped(_from, _to, _tokenContract, _amount);
    }

    /// @notice Send approved funds to a user
    /// @param key The key to check the Transaction struct info
    /// @param to The address to send to
    /// @param tokenContract The contract address of the token to send
    function releaseTokens(
      bytes32 key,
      address to,
      address tokenContract
    ) external onlyOracle nonReentrant {
        Transaction memory txInfo = tokenInfo[key];

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

        emit AmountSent(txInfo.origin, txInfo.destination, tokenContract, amount);
    }

    /// @notice Sends the funds back to the protocol- needs to be after they have fixed the exploit
    /// @param key The key to check the Transaction struct info
    function denyTransaction(bytes32 key) external onlyOracle nonReentrant {
        Transaction memory txInfo = tokenInfo[key];

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
            bool result = IERC20(token).transferFrom(txInfo.destination, token, txInfo.amount);
        }

        emit TransactionDenied(txInfo.destination, txInfo.asset, txInfo.amount);
    }

    /// @notice Set the timelimit for the tx before reverting
    /// @param _timeLimit The time limit in seconds
    function setTimeLimit(uint256 _timeLimit) external onlyOracle {
        timeLimit = _timeLimit;

        emit TimeLimitSet(timeLimit);
    }

    /// @notice Add an address to the whitelist
    /// @param to The addresses to add to the whitelist
    function addToWhitelist(address[] memory to) external onlyOracle {
        for (uint256 i = 0; i < to.length; i++) {
            isWhitelisted[to[i]] = true;

            emit AddressAddedToWhitelist(msg.sender, to[i]);
        }
    }

    /// @notice Approve a withdraw to a user
    /// @param key The key to check the Transaction struct info
    /// @param to The address to approve to
    function approveWithdraw(bytes32 key) external onlyOracle {
        tokenInfo[key].approved = true;

        emit WithdrawApproved(msg.sender, tokenInfo[key].to);
    }

    /// @notice Disapprove a withdraw to a user
    /// @param key The key to check the Transaction struct info
    function disapproveWithdraw(bytes32 key) external onlyOracle {
        tokenInfo[key].approved = false;

        emit WithdrawDisapproved(msg.sender, tokenInfo[key].to);
    }

    /// @dev Add a new oracle
    /// @param _oracle The address of the new oracle
    /// @notice Can only come from a current oracle
    function addOracle(address _oracle) external onlyOracle {
        isOracle[_oracle] = true;

        emit OracleAdded(msg.sender, _oracle);
    }

    /// @dev Get wallet balance for specific wallet
    /// @param key The key to check the Transaction struct info
    /// @return Token amount
    function getWalletBalance(bytes32 key) external returns (uint256) {
        return tokenInfo[key].amount;
    }

    /// @dev Get approval status for specific wallet
    /// @param key The key to check the Transaction struct info
    /// @return Approval status
    function getApprovalStatus(bytes32 key) external returns (bool) {
        return tokenInfo[key].approved;
    }

    /// @dev Hash the transaction information for reads
    /// @param from The address to grab from
    /// @param to The address to send to
    /// @param asset The asset to send
    /// @param amount The amount to send
    function hashTransactionKey(
        address from,
        address to,
        address asset,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to, asset, amount));
    }
}
