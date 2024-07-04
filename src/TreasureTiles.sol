// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title TreasureTiles
 * @dev A blockchain-based game where players bet and select boxes in hopes of finding treasures.
 * Inherits from GelatoVRFConsumerBase for verifiable random functionality and ReentrancyGuard for security.
 */
import { GelatoVRFConsumerBase } from "gelatodigital/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TreasureTiles is GelatoVRFConsumerBase, ReentrancyGuard, Ownable {
    // Custom errors for specific revert conditions
    error TreasureTiles__GameAlreadyExists();
    error TreasureTiles__InvalidBetAmount(uint256 betAmount);
    error TreasureTiles__InvalidBoxeSelection();
    error TreasureTiles__InvalidFundAmount();
    error TreasureTiles__NoFeesToCollect();
    error TreasureTiles__FailedToCollectFees();

    // State variables
    mapping(address => uint256) private s_activeGames; // Tracks active game ID for each player
    mapping(uint256 => uint256) private s_gameBets; // Tracks bet amounts for each game ID
    uint256 private constant MAX_BOXES = 25; // Maximum number of boxes a player can select
    uint256 private constant SERVICE_FEE = 5; // Service fee percentage => 0.5%
    address private s_operatorAddress; // Address of the operator
    uint256 private s_nextGameId = 1; // Incremental ID for each game
    uint256 private s_totalFees;

    // Events
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);

    /**
     * @dev Constructor for initializing the TreasureTiles contract with the operator's address.
     * @param operator Address of the operator responsible for managing the game.
     */
    constructor(address operator, address initialOwner) GelatoVRFConsumerBase() Ownable(initialOwner) {
        s_operatorAddress = operator;
    }

    /**
     * @dev Allows a player to start a game by betting and selecting boxes, including an additional service fee.
     * The total payable amount by the player includes the bet amount plus a service fee calculated as a percentage of
     * the bet amount.
     * Reverts if a game already exists for the player, the bet amount is invalid, the box selection is invalid, or the
     * total payable amount does not match the bet amount plus the service fee.
     * @param selectedBoxes An array of box IDs the player wishes to select, representing their choices in the game.
     * @param betAmount The amount of native token the player wishes to bet. This is exclusive of the service fee.
     */
    function startGame(uint256[] memory selectedBoxes, uint256 betAmount) external payable {
        uint256 fee = betAmount * SERVICE_FEE / 1000;
        if (s_activeGames[msg.sender] != 0) {
            revert TreasureTiles__GameAlreadyExists();
        }
        if (betAmount <= 0) {
            revert TreasureTiles__InvalidBetAmount(betAmount);
        }
        if (selectedBoxes.length <= 0 || selectedBoxes.length > MAX_BOXES) {
            revert TreasureTiles__InvalidBoxeSelection();
        }
        if (msg.value != betAmount + fee) {
            revert TreasureTiles__InvalidFundAmount();
        }

        uint256 gameId = s_nextGameId++;
        s_activeGames[msg.sender] = gameId;
        s_gameBets[gameId] = betAmount;
        s_totalFees += fee;

        // encode the extraData to get the selectedBoxes, betAmount, and gameId
        uint256 requestId = _requestRandomness(abi.encodePacked(selectedBoxes, betAmount, gameId));

        emit GameStarted(gameId, msg.sender, betAmount);
    }

    /**
     * @dev Internal function to handle the randomness fulfillment from Gelato VRF.
     * This function is overridden from GelatoVRFConsumerBase and includes additional game logic.
     * @param randomness The random number provided by Gelato VRF.
     * @param requestId The ID of the randomness request.
     * @param extraData Decoded the data containing the selectedBoxes, betAmount, and gameId.
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
    }

    /**
     * @dev Internal view function to return the operator's address.
     * @return The address of the operator.
     */
    function _operator() internal view override returns (address) {
        return s_operatorAddress;
    }

    /**
     * @dev Allows the owner to collect accumulated fees.
     * Reverts if there are no fees to collect.
     */
    function collectFees() external onlyOwner {
        if (s_totalFees <= 0) {
            revert TreasureTiles__NoFeesToCollect();
        }
        (bool sent,) = owner().call{ value: s_totalFees }("");
        if (!sent) {
            revert TreasureTiles__FailedToCollectFees();
        }
        s_totalFees = 0;
    }

    /**
     * @dev View function to get the total accumulated fees.
     * @return uint256 Total accumulated fees.
     */
    function getFees() external view returns (uint256) {
        return s_totalFees;
    }
}
