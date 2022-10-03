// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

/// @author bmwoolf and zksoju
/// @title Rate limiter for smart contract withdrawals- much like the bank's rate limiter
contract CypherEscrow is ReentrancyGuard {
    mapping(address => bool) isOracle;

    address public token;

    uint256 public tokenThreshold;
    uint256 public timeLimit;
    uint256 public timePeriod;

    /// @notice Whales that are whitelisted to withdraw without rate limiting
    mapping(address => bool) public isWhitelisted;
    /// @notice Request info mapping
    mapping(bytes32 => Transaction) public getTransactionInfo;

    mapping(address => uint256) public getCounterForOrigin;

    /// @notice Withdraw request info
    struct Transaction {
        address origin;
        address destination;
        address asset;
        uint256 amount;
    }

    event AmountSent(bytes32 key, address indexed from, address indexed to, address tokenContract, uint256 amount, uint256 counter);
    event AmountStopped(
        bytes32 key,
        address indexed from,
        address indexed to,
        address tokenContract,
        uint256 amount,
        uint256 counter
    );
    event TransactionAccepted(bytes32 key);
    event TransactionDenied(bytes32 key);
    event OracleAdded(address indexed user, address oracle);
    event TimeLimitSet(uint256 timeLimit);
    event AddressAddedToWhitelist(address indexed user, address whitelist);

    error NotOracle();
    error NotValidAddress();
    error NotApproved();
    error MustBeDisapproved();
    error TransferFailed();

    modifier onlyOracle() {
        bool isAuthorized = isOracle[msg.sender];
        if (!isAuthorized) revert NotOracle();
        _;
    }

    constructor(
        address _token,
        uint256 _tokenThreshold,
        uint256 _timeLimit,
        address[] memory _oracles
    ) {
        token = _token;
        tokenThreshold = _tokenThreshold;
        timeLimit = _timeLimit;

        for (uint256 i = 0; i < _oracles.length; i++) {
            isOracle[_oracles[i]] = true;
        }
    }

    /// @notice Check if an ETH withdraw is valid
    /// @param to The address to withdraw to
    function escrowETH(address from, address to) external payable nonReentrant {
        // check if the stop has been overwritten by protocol owner on the frontend
        // if (msg.sender != sourceContract) revert NotSourceContract();
        if (from == address(0) || to == address(0)) revert NotValidAddress();

        uint256 amount = msg.value;

        // create key hash for getTransactionInfo mapping
        bytes32 key = hashTransactionKey(from, to, getCounterForOrigin[from]);

        Transaction memory txInfo = getTransactionInfo[key];

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[from] == true) {
            (bool success, ) = address(to).call{value: amount}("");

            if (!success) revert TransferFailed();
        } else if (getTransactionInfo[key].origin == address(0)) {
            addToLimiter(key, from, to, address(0), amount);
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
        // if (msg.sender != sourceContract) revert NotSourceContract();
        if (from == address(0) || to == address(0)) revert NotValidAddress();

        // create key hash for getTransactionInfo mapping
        bytes32 key = hashTransactionKey(from, to, getCounterForOrigin[from]);

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[from] == true) {
            bool result = IERC20(asset).transferFrom(from, to, amount);
            if (!result) revert TransferFailed();
        } else if (getTransactionInfo[key].origin == address(0)) {
            bool result = IERC20(asset).transferFrom(from, address(this), amount);
            addToLimiter(key, from, to, asset, amount);
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
        getTransactionInfo[key].origin = _from;
        getTransactionInfo[key].destination = _to;
        getTransactionInfo[key].asset = _tokenContract;
        getTransactionInfo[key].amount = _amount;

        emit AmountStopped(key, _from, _to, _tokenContract, _amount, getCounterForOrigin[_from] += 1);
    }

    /// @notice Send approved funds to a user
    /// @param key The key to check the Transaction struct info
    function acceptTransaction(bytes32 key) external onlyOracle nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

        uint256 amount = txInfo.amount;

        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(txInfo.destination).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(txInfo.asset).transferFrom(address(this), txInfo.destination, txInfo.amount);
            if (!result) revert TransferFailed();
        }

        delete getTransactionInfo[key];

        emit TransactionAccepted(key);
    }

    /// @notice Sends the funds back to the protocol- needs to be after they have fixed the exploit
    /// @param key The key to check the Transaction struct info
    function denyTransaction(bytes32 key) external onlyOracle nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

        // Send ETH back
        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(txInfo.origin).call{value: txInfo.amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Send ERC20 back
            /// TODO: this could be a potential exploit
            address token = txInfo.asset;
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(token).transferFrom(txInfo.destination, txInfo.origin, txInfo.amount);
        }

        delete getTransactionInfo[key];

        emit TransactionDenied(key);
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
    function getTransaction(bytes32 key) external returns (address, uint256) {
        Transaction memory txn = getTransactionInfo[key];
        return (txn.asset, txn.amount);
    }

    /// @dev Hash the transaction information for reads
    /// @param from The address to grab from
    /// @param to The address to send to
    function hashTransactionKey(
        address from,
        address to,
        uint256 counter
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to, counter));
    }
}
