// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title TreasureTiles
 * @dev A blockchain-based game where players bet and select boxes in hopes of finding treasures.
 * Inherits from GelatoVRFConsumerBase for verifiable random functionality and ReentrancyGuard for security.
 */
import { GelatoVRFConsumerBase } from "vrf-contracts/GelatoVRFConsumerBase.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract TreasureTiles is GelatoVRFConsumerBase, ReentrancyGuard, Ownable {
    // Custom errors for specific revert conditions
    error TreasureTiles__BetAmountCantBeZero(uint256 betAmount);
    error TreasureTiles__InvalidTileSelection();
    error TreasureTiles__GameAlreadyExists();
    error TreasureTiles__NoFeesToCollect();
    error TreasureTiles__FailedToCollectFees();
    error TreasureTiles__InsufficientFunds();
    error TreasureTiles__TransactionFailed();
    error TreasureTiles__RandomnessRequestMismatch(uint256 lastRequestId, uint256 _requestId);
    error TreasureTiles__GameDoesNotExist();

    // State variables
    struct Game {
        uint256 selectedTiles;
        uint256 betAmount;
        address player;
        uint256 requestTime;
        uint256 requestBlock;
        uint256 fulfilledTime;
        uint256 fulfilledBlock;
        uint256 randomness;
    }

    mapping(address => uint256) private s_activeGames;
    mapping(uint256 => Game) public s_games;
    uint256 private constant MAX_BOXES = 25; // Maximum number of boxes a player can select
    uint256 private constant SERVICE_FEE = 5; // Service fee percentage => 0.5%
    uint256 private constant ONE_E_EIGHTEEN = 1e18;
    uint256 private constant ONE_E_FIFTEEN = 1e15;
    uint256 private constant ONE_THOUSAND = 1000;
    address private immutable i_operatorAddress; // Address of the operator
    uint256 private s_nextGameId = 0; // Incremental ID for each game
    uint256 private s_totalFees;
    uint256 public nonce;
    bytes32 public latestRandomness;
    uint64 public lastRequestId;

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
    event RandomnessRequested(uint64 requestId);
    event RandomnessFulfilled(uint256 indexed nonce, Game);
    event GameStarted(uint256 indexed gameId, uint256 indexed selectedTiles, uint256 indexed betAmount);

    constructor(address initialOwner, address initialOperator) GelatoVRFConsumerBase() Ownable(initialOwner) {
        i_operatorAddress = initialOperator;
    }

    function startGame(uint256 selectedTiles, uint256 betAmount) external payable {
        // Validate inputs
        if (selectedTiles == 0 || selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        if (betAmount == 0) {
            revert TreasureTiles__BetAmountCantBeZero(betAmount);
        }

        // Assign a unique game ID to the user
        s_nextGameId++;
        s_games[s_nextGameId] = Game({
            selectedTiles: selectedTiles,
            betAmount: betAmount,
            player: msg.sender,
            requestTime: block.timestamp,
            requestBlock: block.number,
            fulfilledTime: 0, // Will be filled later
            fulfilledBlock: 0, // Will be filled later
            randomness: 0 // Will be filled later
         });

        // Request randomness
        this.requestRandomness(abi.encodePacked(s_nextGameId));

        // Emit an event to notify the frontend about the new game
        emit GameStarted(s_nextGameId, selectedTiles, betAmount);
    }

    function requestRandomness(bytes memory _data) external {
        lastRequestId = uint64(_requestRandomness(_data));
        emit RandomnessRequested(lastRequestId);
    }

    function _fulfillRandomness(
        uint256 _randomness,
        uint256 _requestId,
        bytes memory _data
    )
        internal
        virtual
        override
        nonReentrant
    {
        if (lastRequestId != _requestId) {
            revert TreasureTiles__RandomnessRequestMismatch(lastRequestId, _requestId);
        }
        // Decode the gameId from the _data parameter
        uint256 gameId = abi.decode(_data, (uint256));
        if (s_games[gameId].player == address(0)) {
            revert TreasureTiles__GameDoesNotExist();
        }

        // Find the game associated with this request using the decoded gameId
        Game storage game = s_games[gameId];
        game.randomness = _randomness;
        game.fulfilledTime = block.timestamp;
        game.fulfilledBlock = block.number;

        // Update the latest randomness and lastRequestId state variables
        latestRandomness = bytes32(_randomness); // Keep if you need bytes32, otherwise just use _randomness
        lastRequestId = uint64(_requestId);

        uint256 normalizedValue = _randomness % ONE_THOUSAND;
        if (game.selectedTiles == 0 || game.selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        uint256 currentProbability = s_probabilities[game.selectedTiles - 1];
        // Determine the game outcome
        if (normalizedValue * ONE_E_FIFTEEN < currentProbability) {
            // User lost, transfer betAmount to contract's balance
            s_totalFees += game.betAmount; // Assuming all lost betAmounts are considered fees or to be pooled for
            // Delete the game from the mapping
            delete s_games[_requestId];
        } else {
            // User won, calculate wonAmount and fee
            uint256 wonAmount = game.betAmount * s_multipliers[game.selectedTiles - 1] / ONE_E_EIGHTEEN;
            uint256 fee = wonAmount * SERVICE_FEE / ONE_THOUSAND; // Calculating the 0.5% fee
            wonAmount -= fee; // Deducting the fee from the wonAmount
            s_totalFees += fee; // Adding the fee to the total fees

            // Transfer wonAmount to the user
            (bool success,) = payable(game.player).call{ value: wonAmount }("");
            if (!success) {
                revert TreasureTiles__TransactionFailed();
            }
            // Delete the game from the mapping
            delete s_games[_requestId];
        }
        emit RandomnessFulfilled(uint64(_requestId), game);
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
     * @dev Internal view function to return the operator's address.
     * @return The address of the operator.
     */
    function _operator() internal view override returns (address) {
        return i_operatorAddress;
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

    function getServiceFee() external pure returns (uint256) {
        return SERVICE_FEE;
    }
}
