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
    error TreasureTiles__BetAmountCantBeZero(uint256 betAmount);
    error TreasureTiles__InvalidTileSelection();
    error TreasureTiles__GameAlreadyExists();
    error TreasureTiles__GameIdOverflow();
    error TreasureTiles__NoFeesToCollect();
    error TreasureTiles__FailedToCollectFees();
    error TreasureTiles__InsufficientFunds();
    error TreasureTiles__TransactionFailed();
    error TreasureTiles__UnderflowError();

    // State variables
    mapping(address => uint256) private s_activeGames; // Tracks active game ID for each player
    mapping(uint256 => uint256) private s_gameBets; // Tracks bet amounts for each game ID
    uint256 private constant MAX_BOXES = 25; // Maximum number of boxes a player can select
    uint256 private constant SERVICE_FEE = 5; // Service fee percentage => 0.5%
    address private s_operatorAddress; // Address of the operator
    uint256 private s_nextGameId = 1; // Incremental ID for each game
    uint256 private s_totalFees;

    //probabilities of selected tiles
    uint256[25] private s_probabilities = [
        200_000_000_000_000_000,
        360_000_000_000_000_000,
        488_000_000_000_000_000,
        590_400_000_000_000_000,
        672_320_000_000_000_000,
        737_856_000_000_000_000,
        790_284_800_000_000_000,
        832_227_840_000_000_000,
        865_782_272_000_000_000,
        892_625_817_600_000_000,
        914_100_654_080_000_000,
        931_280_523_264_000_000,
        945_024_418_611_200_000,
        956_019_534_888_960_000,
        964_815_627_911_168_000,
        971_852_502_328_934_400,
        977_482_001_863_147_520,
        981_985_601_490_518_400,
        985_588_481_192_414_720,
        988_470_784_953_931_520,
        990_776_627_963_145_344,
        992_621_302_370_516_224,
        994_097_041_896_412_928,
        995_277_633_517_130_496,
        996_222_106_813_704_320
    ];

    //exponential multipliers between 1 and 5
    uint256[25] private s_multipliers = [
        1_006_400_000_000_000_000,
        1_025_600_000_000_000_000,
        1_057_600_000_000_000_000,
        1_102_400_000_000_000_000,
        1_160_000_000_000_000_000,
        1_230_400_000_000_000_000,
        1_313_600_000_000_000_000,
        1_409_600_000_000_000_000,
        1_518_400_000_000_000_000,
        1_640_000_000_000_000_000,
        1_774_400_000_000_000_000,
        1_921_600_000_000_000_000,
        2_081_600_000_000_000_000,
        2_254_400_000_000_000_000,
        2_440_000_000_000_000_000,
        2_638_400_000_000_000_000,
        2_849_600_000_000_000_000,
        3_073_600_000_000_000_000,
        3_310_400_000_000_000_000,
        3_560_000_000_000_000_000,
        3_822_400_000_000_000_000,
        4_097_600_000_000_000_000,
        4_385_600_000_000_000_000,
        4_686_400_000_000_000_000,
        5_000_000_000_000_000_000
    ];

    // Events
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);
    event GameOutcome(uint256 indexed gameId, address indexed player, string indexed outcome, uint256 amount);

    /**
     * @dev Initializes the TreasureTiles contract, setting the operator and the initial owner.
     * Inherits initialization from GelatoVRFConsumerBase and Ownable contracts.
     * @param initialOwner The address of the initial owner with administrative privileges. responsible for managing
     * game mechanics.
     */
    constructor(address initialOwner) GelatoVRFConsumerBase() Ownable(initialOwner) {
        s_operatorAddress = initialOwner;
    }

    /**
     * @dev Initiates a new game session for a player by accepting a bet and selected tiles. The function requires the
     * player to send an amount of native token that covers the bet. The service fee, if applicable, is deducted from
     * the winning amount instead of being added to the bet amount.
     *
     * This function also requests randomness for the game session by encoding the selected tiles, bet amount, and game
     * ID, ensuring the game's fairness and unpredictability.
     *
     * Emits a `GameStarted` event upon successful creation of a game session, indicating the game's initiation with the
     * game ID, player's address, and bet amount.
     *
     * Requirements:
     * - The player must not have an active game session.
     * - The bet amount, represented by `msg.value`, must be greater than 0.
     * - The number of selected tiles must be valid (within the allowed range).
     *
     * Reverts with:
     * - `TreasureTiles__GameAlreadyExists` if the player already has an active game.
     * - `TreasureTiles__BetAmountCantBeZero` if the bet amount (`msg.value`) is 0 or less.
     * - `TreasureTiles__InvalidTileSelection` if the selected tiles are outside the allowed range.
     *
     * @param selectedTiles The number representing the tiles selected by the player for this game session.
     */
    function startGame(uint256 selectedTiles) external payable nonReentrant {
        uint256 betAmount = msg.value;
        if (selectedTiles == 0 || selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        if (betAmount == 0) {
            revert TreasureTiles__BetAmountCantBeZero(betAmount);
        }
        if (s_activeGames[msg.sender] != 0) {
            revert TreasureTiles__GameAlreadyExists();
        }

        uint256 gameId = s_nextGameId++;
        s_activeGames[msg.sender] = gameId;
        s_gameBets[gameId] = betAmount;

        // encode the extraData to get the selectedTiles, betAmount, and gameId
        bytes memory data = abi.encode(selectedTiles, betAmount, gameId);
        _requestRandomness(data);

        emit GameStarted(gameId, msg.sender, betAmount);
    }

    /**
     * @dev Handles the randomness fulfillment from Gelato VRF for the Treasure Tiles game.
     * This overridden function from GelatoVRFConsumerBase processes the game outcome based on the received random
     * number. It decodes extra data to extract game parameters, calculates win/loss based on predefined probabilities,
     * updates game state, and manages payouts or fund deductions accordingly. The service fee is deducted from the
     * winning amount.
     *
     * Emits a `GameOutcome` event indicating the result of the game.
     *
     * Reverts with `TreasureTiles__InsufficientFunds` if the contract does not have enough funds to cover a win.
     * Reverts with `TreasureTiles__TransactionFailed` if sending the win amount to the player fails.
     *
     * @param randomness The random number provided by Gelato VRF, used to determine the game outcome.
     * @param data Encoded data containing the selectedTiles (number of tiles chosen by the player),
     * betAmount (the amount of native token wagered), and gameId (unique identifier for the game session).
     */
    function _fulfillRandomness(
        uint256 randomness,
        uint256,
        bytes memory data
    )
        internal
        virtual
        override
        nonReentrant
    {
        // Decode the extraData to get the selectedTiles, betAmount, and gameId
        (uint256 selectedTiles, uint256 betAmount, uint256 gameId) = abi.decode(data, (uint256, uint256, uint256));
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
