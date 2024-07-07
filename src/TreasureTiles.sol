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
    error TreasureTiles__InvalidTileSelection();
    error TreasureTiles__InvalidFundAmount();
    error TreasureTiles__NoFeesToCollect();
    error TreasureTiles__FailedToCollectFees();
    error TreasureTiles__InsufficientFunds();
    error TreasureTiles__TransactionFailed();

    // State variables
    mapping(address => uint256) private s_activeGames; // Tracks active game ID for each player
    mapping(uint256 => uint256) private s_gameBets; // Tracks bet amounts for each game ID
    mapping(uint256 => bool) private s_requestIdOutcomes; // Maps requestId to a boolean game's outcome (T=win,F=lose)
    uint256 private constant MAX_BOXES = 25; // Maximum number of boxes a player can select
    uint256 private constant SERVICE_FEE = 5; // Service fee percentage => 0.5%
    address private s_operatorAddress; // Address of the operator
    uint256 private s_nextGameId = 1; // Incremental ID for each game
    uint256 private s_totalFees;

    //10^16 exponential multipliers between 1 and 5
    uint256[25] private s_multipliers = [
        2_000_000_000_000_000,
        3_600_000_000_000_000,
        4_880_000_000_000_000,
        5_904_000_000_000_000,
        6_723_200_000_000_000,
        7_378_560_000_000_000,
        7_902_848_000_000_000,
        8_322_278_400_000_000,
        8_657_822_720_000_000,
        8_926_258_176_000_000,
        9_141_006_540_800_000,
        9_312_805_232_640_000,
        9_450_244_186_112_000,
        9_560_195_348_889_600,
        9_648_156_279_111_680,
        9_718_525_023_289_344,
        9_774_820_018_631_475,
        9_819_856_014_905_180,
        9_855_884_811_924_144,
        9_884_707_849_539_315,
        9_907_766_279_631_453,
        9_926_213_023_705_162,
        9_940_970_418_964_129,
        9_952_776_335_171_304,
        9_962_221_068_137_043
    ];

    //10^4 probabilities of selected tiles
    uint256[25] private s_probabilities = [
        10_064,
        10_256,
        10_576,
        11_024,
        11_600,
        12_304,
        13_136,
        14_096,
        15_184,
        16_400,
        17_744,
        19_216,
        20_816,
        22_544,
        24_400,
        26_384,
        28_496,
        30_736,
        33_104,
        35_600,
        38_224,
        40_976,
        43_856,
        46_864,
        50_000
    ];

    // Events
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);
    event GameOutcome(uint256 indexed gameId, address indexed player, string indexed outcome, uint256 amount);

    /**
     * @dev Constructor for initializing the TreasureTiles contract with the operator's address.
     * @param operator Address of the operator responsible for managing the game.
     */
    constructor(address operator, address initialOwner) GelatoVRFConsumerBase() Ownable(initialOwner) {
        s_operatorAddress = operator;
    }

    /**
     * @dev Initiates a new game session for a player by accepting a bet and selected boxes, factoring in a service fee.
     * This function requires the player to send an amount of native token that covers both the bet and the service fee.
     * The service fee is a percentage of the bet amount, defined by `SERVICE_FEE`.
     *
     * Emits a `GameStarted` event upon successful creation of a game session.
     *
     * Requirements:
     * - The player must not have an active game session.
     * - The bet amount must be greater than 0.
     * - The number of selected boxes must be valid (within the allowed range).
     * - The total sent value must exactly match the sum of the bet amount and the calculated service fee.
     *
     * Reverts with:
     * - `TreasureTiles__GameAlreadyExists` if the player already has an active game.
     * - `TreasureTiles__InvalidBetAmount` if the bet amount is 0 or less.
     * - `TreasureTiles__InvalidBoxSelection` if the selected boxes are outside the allowed range.
     * - `TreasureTiles__InvalidFundAmount` if the sent value does not match the required total of bet amount plus
     * service fee.
     *
     * @param selectedTiles The number representing the boxes selected by the player for this game session.
     * @param betAmount The amount of native token the player is betting, excluding the service fee.
     */
    function startGame(uint256 selectedTiles, uint256 betAmount) external payable nonReentrant {
        uint256 fee = (betAmount * SERVICE_FEE) / 1000;
        if (s_activeGames[msg.sender] != 0) {
            revert TreasureTiles__GameAlreadyExists();
        }
        if (betAmount <= 0) {
            revert TreasureTiles__InvalidBetAmount(betAmount);
        }
        if (selectedTiles <= 0 || selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        if (msg.value != betAmount + fee) {
            revert TreasureTiles__InvalidFundAmount();
        }

        uint256 gameId = s_nextGameId++;
        s_activeGames[msg.sender] = gameId;
        s_gameBets[gameId] = betAmount;
        s_totalFees += fee;

        // encode the extraData to get the selectedTiles, betAmount, and gameId
        _requestRandomness(abi.encode(selectedTiles, betAmount, gameId));

        emit GameStarted(gameId, msg.sender, betAmount);
    }

    /**
     * @dev Handles the randomness fulfillment from Gelato VRF for the Treasure Tiles game.
     * This overridden function from GelatoVRFConsumerBase processes the game outcome based on the received random
     * number.
     * It decodes extra data to extract game parameters, calculates win/loss based on predefined probabilities,
     * updates game state, and manages payouts or fund deductions accordingly.
     *
     * Emits a `GameOutcome` event indicating the result of the game.
     *
     * Reverts with `TreasureTiles__InsufficientFunds` if the contract does not have enough funds to cover a win.
     * Reverts with `TreasureTiles__TransactionFailed` if sending the win amount to the player fails.
     *
     * @param randomness The random number provided by Gelato VRF, used to determine the game outcome.
     * @param requestId The ID of the VRF request, used to track the game outcome.
     * @param extraData Encoded data containing the selectedTiles (number of boxes chosen by the player),
     * betAmount (the amount of ETH wagered), and gameId (unique identifier for the game session).
     */
    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory extraData
    )
        internal
        virtual
        override
        nonReentrant
    {
        // Decode the extraData to get the selectedTiles, betAmount, and gameId
        (uint256 selectedTiles, uint256 betAmount, uint256 gameId) = abi.decode(extraData, (uint256, uint256, uint256));
        uint256 normalizedValue = randomness % 1000;
        uint256 currentProbability = s_probabilities[selectedTiles - 1];
        uint256 wonAmount;

        if (normalizedValue < currentProbability) {
            // lost
            s_requestIdOutcomes[requestId] = false; // Mark the game as lost
            emit GameOutcome(gameId, msg.sender, "Lost", 0); // Emitting event for loss
        } else {
            // won
            wonAmount = (betAmount * s_multipliers[selectedTiles - 1]) / 1e16;
            if (address(this).balance < wonAmount) {
                revert TreasureTiles__InsufficientFunds();
            }

            (bool sent,) = msg.sender.call{ value: wonAmount }("");

            if (!sent) {
                revert TreasureTiles__TransactionFailed();
            }
            s_requestIdOutcomes[requestId] = true; // Mark the game as won
            emit GameOutcome(gameId, msg.sender, "Won", wonAmount); // Emitting event for win
        }

        delete s_activeGames[msg.sender];
        delete s_gameBets[gameId];
    }

    /**
     * @dev Internal view function to return the operator's address.
     * @return The address of the operator.
     */
    function _operator() internal view override returns (address) {
        return s_operatorAddress;
    }

    /**
     * @dev Transfers all accumulated service fees to the contract owner.
     * This function allows the contract owner to withdraw the accumulated service fees from the contract.
     * The withdrawal involves sending the total accumulated fees to the owner's address.
     *
     * Emits a native `Transfer` event upon successful transfer of fees.
     *
     * Requirements:
     * - The caller must be the contract owner.
     * - There must be fees available to collect; otherwise, it reverts.
     *
     * Reverts with:
     * - `TreasureTiles__NoFeesToCollect` if there are no fees available for collection.
     * - `TreasureTiles__FailedToCollectFees` if the transfer of fees to the owner fails.
     */
    function collectFees() external onlyOwner nonReentrant {
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
     * @dev Returns the total amount of service fees accumulated in the contract.
     * This view function provides the total service fees that have been collected from game activities and are
     * available for withdrawal by the contract owner.
     *
     * @return uint256 The total accumulated service fees in wei.
     */
    function getFees() external view returns (uint256) {
        return s_totalFees;
    }
}
