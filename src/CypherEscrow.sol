// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

/// @title Cypher Escrow System
/// @author bmwoolf
/// @author zksoju
/// @notice Rate limiter for smart contract withdrawals- much like the bank's rate limiter
contract CypherEscrow is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                            ESCROW STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the token being stored in the escrow
    address public token;

    /// @notice The amount of tokens that will create an escrow
    uint256 public tokenThreshold;

    /// @notice The amount of time before the funds can be released if no response from the verifiers
    uint256 public timeLimit;

    /// @notice Allowed verifier addresses to sign off on escrowed transactions
    mapping(address => bool) isVerifier;

    /// @notice Whales that are whitelisted to withdraw without rate limiting
    mapping(address => bool) public isWhitelisted;

    /// @notice Request info mapping
    mapping(bytes32 => Transaction) public getTransactionInfo;

    /// @notice The counter for the source contract
    mapping(address => uint256) public getCounterForOrigin;

    /// @notice Withdraw request info
    struct Transaction {
        address origin;
        address protocol;
        address dst;
        address asset;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

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
    event VerifierAdded(address indexed user, address verifier);
    event TimeLimitSet(uint256 timeLimit);
    event AddressAddedToWhitelist(address indexed user, address whitelist);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotVerifier();
    error NotValidAddress();
    error NotApproved();
    error MustBeDisapproved();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVerifier() {
        bool isAuthorized = isVerifier[msg.sender];
        if (!isAuthorized) revert NotVerifier();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _token,
        uint256 _tokenThreshold,
        uint256 _timeLimit,
        address[] memory _verifiers
    ) {
        token = _token;
        tokenThreshold = _tokenThreshold;
        timeLimit = _timeLimit;

        for (uint256 i = 0; i < _verifiers.length; i++) {
            isVerifier[_verifiers[i]] = true;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ESCROW LOGIC
    //////////////////////////////////////////////////////////////*/

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
            if (!result) revert TransferFailed();
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

    /*//////////////////////////////////////////////////////////////
                          VERIFIER AUTH LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Send approved funds to a user
    /// @param key The key to check the Transaction struct info
    function acceptTransaction(bytes32 key) external onlyVerifier nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

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
    function denyTransaction(bytes32 key, address to) external onlyVerifier nonReentrant {
        Transaction memory txInfo = getTransactionInfo[key];

        // update storage first to prevent reentrancy
        delete getTransactionInfo[key];

        // Send ETH back
        if (txInfo.asset == address(0x0)) {
            (bool success, ) = address(to).call{value: txInfo.amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Send ERC20 back
            /// @notice Our contract needs approval to swap tokens
            bool result = IERC20(txInfo.asset).transferFrom(address(this), to, txInfo.amount);
            if (!result) revert TransferFailed();
        }

        emit TransactionDenied(key);
    }

    /*//////////////////////////////////////////////////////////////
                              SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the timelimit for the tx before reverting
    /// @param _timeLimit The time limit in seconds
    function setTimeLimit(uint256 _timeLimit) external onlyVerifier {
        timeLimit = _timeLimit;

        emit TimeLimitSet(timeLimit);
    }

    /// @notice Add an address to the whitelist
    /// @param to The addresses to add to the whitelist
    function addToWhitelist(address[] memory to) external onlyVerifier {
        for (uint256 i = 0; i < to.length; i++) {
            isWhitelisted[to[i]] = true;

            emit AddressAddedToWhitelist(msg.sender, to[i]);
        }
    }

    /// @dev Add a new verifier
    /// @param _verifier The address of the new verifier
    /// @notice Can only come from a current verifier
    function addVerifier(address _verifier) external onlyVerifier {
        isVerifier[_verifier] = true;

        emit VerifierAdded(msg.sender, _verifier);
    }

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Get wallet balance for specific wallet
    /// @param key The key to check the Transaction struct info
    /// @return Token amount
    function getTransaction(bytes32 key) external view returns (address, uint256) {
        Transaction memory txn = getTransactionInfo[key];
        return (txn.asset, txn.amount);
    }

    /*//////////////////////////////////////////////////////////////
                              UTILS
    //////////////////////////////////////////////////////////////*/

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
