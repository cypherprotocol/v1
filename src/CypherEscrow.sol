// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

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
        address protocol;
        address dst;
        address asset;
        uint256 amount;
    }

    event AmountStopped(
        bytes32 key,
        address indexed origin,
        address indexed protocol,
        address indexed dst,
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
    /// @param origin The address of the user who initiated the withdraw
    /// @param dst The address of the user who will receive the ETH
    function escrowETH(address origin, address dst) external payable nonReentrant {
        // check if the stop has been overwritten by protocol owner on the frontend
        // if (msg.sender != sourceContract) revert NotSourceContract();
        if (origin == address(0) || dst == address(0)) revert NotValidAddress();

        uint256 amount = msg.value;

        // create key hash for getTransactionInfo mapping
        bytes32 key = hashTransactionKey(origin, msg.sender, dst, getCounterForOrigin[origin]);

        Transaction memory txInfo = getTransactionInfo[key];

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[dst]) {
            (bool success, ) = address(dst).call{value: amount}("");

            if (!success) revert TransferFailed();
        } else if (getTransactionInfo[key].origin == address(0)) {
            addToLimiter(key, origin, msg.sender, dst, address(0), amount);
        }
    }

    /// @notice Check if an ERC20 withdraw is valid
    /// @param origin The address of the user who initiated the withdraw
    /// @param dst The address to transfer to
    /// @param asset The ERC20 token contract to withdraw from
    /// @param amount The amount to withdraw
    function escrowTokens(
        address origin,
        address dst,
        address asset,
        uint256 amount
    ) external {
        // check if the stop has been overwritten by protocol owner on the frontend
        // if (msg.sender != sourceContract) revert NotSourceContract();
        if (origin == address(0) || dst == address(0)) revert NotValidAddress();

        // create key hash for getTransactionInfo mapping
        bytes32 key = hashTransactionKey(origin, msg.sender, dst, getCounterForOrigin[origin]);

        // if they are whitelisted or amount is less than threshold, just transfer the tokens
        if (amount < tokenThreshold || isWhitelisted[origin]) {
            bool result = IERC20(asset).transferFrom(msg.sender, dst, amount);
            if (!result) revert TransferFailed();
        } else if (getTransactionInfo[key].origin == address(0)) {
            bool result = IERC20(asset).transferFrom(msg.sender, address(this), amount);
            addToLimiter(key, origin, msg.sender, dst, asset, amount);
        }
    }

    /// @notice Add a user to the limiter
    /// @param key The key to check the Transaction struct info
    /// @param origin The address of the user who initiated the withdraw
    /// @param protocol The address of the protocol to withdraw from
    /// @param dst The address to transfer to
    /// @param amount The amount to add to the limiter
    function addToLimiter(
        bytes32 key,
        address origin,
        address protocol,
        address dst,
        address asset,
        uint256 amount
    ) internal {
        getTransactionInfo[key].origin = origin;
        getTransactionInfo[key].protocol = protocol;
        getTransactionInfo[key].dst = dst;
        getTransactionInfo[key].asset = asset;
        getTransactionInfo[key].amount = amount;

        emit AmountStopped(key, origin, protocol, dst, asset, amount, getCounterForOrigin[origin] += 1);
    }

    /// @notice Send approved funds to a user
    /// @param key The key to check the Transaction struct info
    function acceptTransaction(bytes32 key) external onlyOracle nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

        if (txInfo.origin == address(0)) revert NotValidAddress();

        uint256 amount = txInfo.amount;
        delete getTransactionInfo[key];

        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(txInfo.dst).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(txInfo.asset).transferFrom(address(this), txInfo.dst, txInfo.amount);
            if (!result) revert TransferFailed();
        }

        emit TransactionAccepted(key);
    }

    /// @notice Sends the funds back to the protocol- needs to be after they have fixed the exploit
    /// @param key The key to check the Transaction struct info
    /// @param to Address to redirect the funds to (in case protocol is compromised or cannot handle the funds)
    function denyTransaction(bytes32 key, address to) external onlyOracle nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

        // update storage first to prevent reentrancy
        delete getTransactionInfo[key];

        // Send ETH back
        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(to).call{value: txInfo.amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Send ERC20 back
            /// TODO: this could be a potential exploit
            address token = txInfo.asset;
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(token).transferFrom(address(this), to, txInfo.amount);
        }

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
    /// @param origin Origin caller
    /// @param protocol The protocol to grab fund from
    /// @param dst The address to send to
    function hashTransactionKey(
        address origin,
        address protocol,
        address dst,
        uint256 counter
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(origin, protocol, dst, counter));
    }
}
