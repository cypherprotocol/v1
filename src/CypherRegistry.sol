// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CypherEscrow} from "./CypherEscrow.sol";
import {ICypherProtocol} from "./interfaces/ICypherProtocol.sol";

/// @title Cypher Escrow System Registry
/// @author bmwoolf
/// @author zksoju
/// @notice Registry for storing the escrows for a protocol
contract CypherRegistry {
    /*//////////////////////////////////////////////////////////////
                            REGISTRY STATE
    //////////////////////////////////////////////////////////////*/

    mapping(address => CypherEscrow) public getEscrowForProtocol;

    /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    event EscrowCreated(
        address indexed escrow,
        address[] indexed protocols,
        address token,
        uint256 tokenThreshold,
        uint256 timeLimit,
        address[] oracles
    );
    event EscrowAttached(address indexed escrow, address[] indexed protocol);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ProtocolAlreadyRegistered();
    error NotAnArchitect();

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier architectOnly(address[] memory protocols) {
        for (uint256 i = 0; i < protocols.length; i++) {
            if (ICypherProtocol(protocols[i]).getArchitect() != msg.sender) revert NotAnArchitect();
        }
        _;
    }

    modifier notRegistered(address[] memory protocols) {
        for (uint256 i = 0; i < protocols.length; i++) {
            if (address(getEscrowForProtocol[protocols[i]]) != address(0)) revert ProtocolAlreadyRegistered();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {}

    /*//////////////////////////////////////////////////////////////
                            CREATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates a new escrow for a protocol
    /// @param protocols The set of contracts to protect
    /// @param token The address of the token that is being stored in the protocols smart contracts
    /// @param tokenThreshold The amount per tx to limit on withdraw
    /// @param timeLimit How long the funds should stay locked up until release (if the team does not respond)
    /// @param oracles The addresses of the signers who can release the funds
    function createEscrow(
        address[] memory protocols,
        address token,
        uint256 tokenThreshold,
        uint256 timeLimit,
        address[] memory oracles
    ) public architectOnly(protocols) notRegistered(protocols) returns (address) {
        CypherEscrow escrow = new CypherEscrow(token, tokenThreshold, timeLimit, oracles);

        for (uint256 i = 0; i < protocols.length; i++) {
            getEscrowForProtocol[protocols[i]] = escrow;
        }

        emit EscrowCreated(address(escrow), protocols, token, tokenThreshold, timeLimit, oracles);

        return address(escrow);
    }

    /// @dev Assigns an existing escrow to a set of protocols
    function attachEscrow(address escrow, address[] memory protocols) public architectOnly(protocols) {
        for (uint256 i = 0; i < protocols.length; i++) {
            getEscrowForProtocol[protocols[i]] = CypherEscrow(escrow);
        }

        emit EscrowAttached(escrow, protocols);
    }
}
