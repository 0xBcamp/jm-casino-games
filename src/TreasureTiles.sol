// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title TreasureTiles
 * @dev A blockchain-based game where players bet and select boxes in hopes of finding treasures.
 * Inherits from GelatoVRFConsumerBase for verifiable random functionality and ReentrancyGuard for security.
 */
import { GelatoVRFConsumerBase } from "gelatodigital/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TreasureTiles is GelatoVRFConsumerBase, ReentrancyGuard {
    // Custom errors for specific revert conditions
    error TreasureTiles__GameAlreadyExists();
    error TreasureTiles__InvalidBetAmount(uint256 betAmount);
    error TreasureTiles__InvalidBoxeSelection();

    // State variables
    mapping(address => uint256) private activeGames; // Tracks active game ID for each player
    mapping(uint256 => uint256) private gameBets; // Tracks bet amounts for each game ID
    address private s_operatorAddress; // Address of the operator
    uint256 private nextGameId = 1; // Incremental ID for each game
    uint256 constant MAX_BOXES = 25; // Maximum number of boxes a player can select

    // Events
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);

    /**
     * @dev Constructor for initializing the TreasureTiles contract with the operator's address.
     * @param operator Address of the operator responsible for managing the game.
     */
    constructor(address operator) GelatoVRFConsumerBase() {
        s_operatorAddress = operator;
    }

    /**
     * @dev Allows a player to start a game by betting and selecting boxes.
     * Reverts if a game already exists for the player, the bet amount is invalid, or the box selection is invalid.
     * @param selectedBoxes An array of box IDs the player wishes to select.
     * @param betAmount The amount of native token the player wishes to bet.
     */
    function startGame(uint256[] memory selectedBoxes, uint256 betAmount) external payable {
        if (activeGames[msg.sender] != 0) {
            revert TreasureTiles__GameAlreadyExists();
        }
        if (betAmount <= 0) {
            revert TreasureTiles__InvalidBetAmount(betAmount);
        }
        if (selectedBoxes.length <= 0 || selectedBoxes.length > MAX_BOXES) {
            revert TreasureTiles__InvalidBoxeSelection();
        }

        uint256 gameId = nextGameId++;
        activeGames[msg.sender] = gameId;
        gameBets[gameId] = betAmount;

        // encode the extraData to get the selectedBoxes, betAmount, and gameId
        uint256 requestId = _requestRandomness(abi.encodePacked(selectedBoxes, betAmount, gameId));

        emit GameStarted(gameId, msg.sender, betAmount);
    }

    /**
     * @dev Internal function to handle the randomness fulfillment from Gelato VRF.
     * This function is overridden from GelatoVRFConsumerBase and includes additional game logic.
     * @param randomness The random number provided by Gelato VRF.
     * @param requestId The ID of the randomness request.
     * @param extraData Encoded data containing the selectedBoxes, betAmount, and gameId.
     */
    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory extraData
    )
        internal
        override
        nonReentrant
    {
        // Decode the extraData to get the selectedBoxes, betAmount, and gameId
        (uint256[] memory selectedBoxes, uint256 betAmount, uint256 gameId) =
            abi.decode(extraData, (uint256[], uint256, uint256));

        /* Game logic to be implemented */

        // Retrieve the game from storage using the gameId
        // Check if the game exists, if not, revert the transaction
    }

    /**
     * @dev Internal view function to return the operator's address.
     * @return The address of the operator.
     */
    function _operator() internal view override returns (address) {
        return s_operatorAddress;
    }
}
