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
    error TreasureTiles__BetAmountCantBeZero();
    error TreasureTiles__InvalidTileSelection();
    error TreasureTiles__NoFeesToCollect();
    error TreasureTiles__FailedToCollectFees();
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
    uint256 private constant ONE_E_THREE = 1e3;
    uint256 private constant ONE_THOUSAND = 1000;
    address private immutable i_operatorAddress; // Address of the operator
    uint256 private s_nextGameId = 0; // Incremental ID for each game
    uint256 private s_totalFees;
    uint256 private s_liquidityPool; // game liquidity
    address public feeRecipient;

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
    event RandomnessRequested(uint64 indexed requestId);
    event RandomnessFulfilled(uint256 indexed gameId, uint256 indexed nonce, Game);
    event FeeCollected(uint256 indexed amount);

    /**
     * @notice Initializes the contract with an owner, operator, and fee recipient.
     * @param initialOwner The initial owner of the contract.
     * @param _initialOperator The initial operator address.
     * @param _feeRecipient The initial fee recipient address.
     */
    constructor(
        address initialOwner,
        address _initialOperator,
        address _feeRecipient
    )
        GelatoVRFConsumerBase()
        Ownable(initialOwner)
    {
        i_operatorAddress = _initialOperator;
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Updates the address designated to receive fees.
     * @dev Allows the contract owner to change the fee recipient at any time.
     * This is crucial for flexibility in managing funds, especially in scenarios where the original recipient might
     * change roles or cease operations.
     *
     * @param newFeeRecipient The Ethereum address to which future fees will be sent.
     *
     * Requirements:
     * - The caller must be the contract owner.
     */
    function updateFeeRecipient(address newFeeRecipient) external onlyOwner {
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Initiates a new game instance with specified parameters.
     * @dev Validates the input parameters to ensure they meet the game's requirements.
     * It then creates a new game entry in the internal mapping and requests randomness from the VRF oracle.
     *
     * @param selectedTiles The number of tiles chosen by the player for the game.
     * @param betAmount The amount of Ether wagered by the player for the game.
     *
     * Requirements:
     * - `selectedTiles` must be greater than 0 and less than or equal to `MAX_BOXES`.
     * - `betAmount` must be greater than 0.
     *
     * Emits:
     * - `RandomnessRequested`: Indicates that a new randomness request has been made.
     */
    function startGame(uint256 selectedTiles, uint256 betAmount) external payable returns (uint256) {
        // Validate inputs
        if (selectedTiles == 0 || selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        if (betAmount == 0) {
            revert TreasureTiles__BetAmountCantBeZero();
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
        return s_nextGameId;
    }

    /**
     * @notice Requests randomness from the VRF oracle.
     * @dev Encapsulates the logic to request a new piece of randomness from the oracle.
     * This randomness is essential for determining the outcome of the game.
     *
     * @param _data Encoded data that includes the game ID, used to identify the specific game for which randomness is
     * being requested.
     *
     * Emits:
     * - `RandomnessRequested`: Notifies listeners that a new randomness request has been initiated.
     */
    function requestRandomness(bytes memory _data) external {
        lastRequestId = uint64(_requestRandomness(_data));
        emit RandomnessRequested(lastRequestId);
    }

    /**
     * @notice Processes the received randomness to determine the game outcome.
     * @dev Decodes the game ID from the provided data, retrieves the corresponding game record, and applies the
     * randomness to decide the winner.
     * Depending on the outcome, it calculates the winnings, deducts fees, and transfers the winnings to the player.
     *
     * @param _randomness The generated random number provided by the VRF oracle.
     * @param _requestId The ID of the randomness request, used to match the request with its result.
     * @param _data Encoded data that includes the game ID, used to retrieve the specific game record.
     *
     * Requirements:
     * - The request ID must match the ID of the pending request.
     * - The game must exist in the internal mapping.
     *
     * Modifiers:
     * - `nonReentrant`: Prevents reentrancy attacks by disallowing recursive calls.
     *
     * Emits:
     * - `RandomnessFulfilled`: Indicates that the randomness has been processed and the game outcome determined.
     */
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

        if (game.selectedTiles == 0 || game.selectedTiles > MAX_BOXES) {
            revert TreasureTiles__InvalidTileSelection();
        }
        if (game.betAmount == 0) {
            revert TreasureTiles__BetAmountCantBeZero();
        }

        // Update the latest randomness and lastRequestId state variables
        latestRandomness = bytes32(_randomness); // Keep if you need bytes32, otherwise just use _randomness
        lastRequestId = uint64(_requestId);
        uint256 normalizedValue = _randomness % ONE_THOUSAND;
        uint256 currentProbability = s_probabilities[game.selectedTiles - 1];

        // Determine the game outcome
        if (normalizedValue <= currentProbability * ONE_E_FIFTEEN) {
            // User lost, add betAmount to liquidity pool instead of fees
            s_liquidityPool += game.betAmount;
            // Delete the game from the mapping
            delete s_games[_requestId];
        } else {
            // User won, calculate wonAmount and fee
            uint256 wonAmount = game.betAmount * s_multipliers[game.selectedTiles - 1] / ONE_E_EIGHTEEN;
            uint256 fee = (wonAmount * SERVICE_FEE) / ONE_E_THREE; // Calculating the 0.5% fee
            uint256 wonAmountAfterFees = wonAmount - fee; // Deducting the fee from the wonAmount
            s_totalFees += fee; // Adding the fee to the total fees

            // Delete the game from the mapping
            delete s_games[_requestId];

            // Transfer wonAmount to the user
            (bool success,) = payable(game.player).call{ value: wonAmountAfterFees }("");
            if (!success) {
                revert TreasureTiles__TransactionFailed();
            }
        }
        emit RandomnessFulfilled(gameId, uint64(_requestId), game);
    }

    /**
     * @notice Collects all accumulated fees and sends them to the designated fee recipient.
     * @dev This function resets the total fees collected after transferring the funds to the fee recipient.
     * It emits a `FeeCollected` event with the amount transferred.
     * Only callable by the owner due to the `onlyOwner` modifier.
     * Reverts if there are no fees to collect or if the transfer fails.
     */
    function collectFees() external onlyOwner {
        if (s_totalFees == 0) {
            revert TreasureTiles__NoFeesToCollect();
        }

        uint256 feesToSend = s_totalFees;
        s_totalFees = 0;

        (bool sent,) = feeRecipient.call{ value: feesToSend }("");
        if (!sent) {
            revert TreasureTiles__FailedToCollectFees();
        }

        emit FeeCollected(feesToSend);
    }

    /**
     * @dev Internal view function returning the address of the operator.
     * This function is overridden from the base contract and provides access to the operator's address within the
     * contract.
     * Useful for external contracts or services interacting with this contract to identify the operator.
     * @return The address of the operator.
     */
    function _operator() internal view override returns (address) {
        return i_operatorAddress;
    }

    /**
     * @notice Retrieves the total amount of fees that have been collected through the contract.
     * @dev This function provides transparency into the financial operations of the contract by reporting the
     * cumulative fees collected.
     * It is accessible externally for querying purposes.
     * @return The total amount of fees collected, represented as a `uint256`.
     */
    function getFees() external view returns (uint256) {
        return s_totalFees;
    }

    /**
     * @notice Provides the service fee percentage applied to winnings.
     * @dev This constant represents the percentage of winnings that are deducted as a service fee before being
     * distributed to players.
     * It is defined at compile time and cannot be changed post-deployment.
     * @return The service fee percentage as a `uint256`.
     */
    function getServiceFee() external pure returns (uint256) {
        return SERVICE_FEE;
    }

    /**
     * @notice Retrieves the probability array for each tile selection.
     * @dev This array defines the odds for each tile selection in the game, influencing the distribution of winnings.
     * Probabilities are used to determine the likelihood of winning based on the selected tiles.
     * @return An array of `uint256` representing the probability for each tile selection.
     */
    function getProbabilities() public view returns (uint256[25] memory) {
        return s_probabilities;
    }

    /**
     * @notice Retrieves the multiplier array for each tile selection.
     * @dev Multipliers adjust the payout amounts for winning selections, enhancing the game's dynamic nature.
     * Higher multipliers correspond to higher payouts for successful bets.
     * @return An array of `uint256` representing the multiplier for each tile selection.
     */
    function getMultipliers() public view returns (uint256[25] memory) {
        return s_multipliers;
    }

    /**
     * @notice Obtains the current balance of the liquidity pool.
     * @dev The liquidity pool accumulates funds from unsuccessful bets, serving as a reserve for the contract's
     * operations.
     * This function allows stakeholders to monitor the health and stability of the liquidity pool.
     * @return The current balance of the liquidity pool as a `uint256`.
     */
    function getLiquidityPool() public view returns (uint256) {
        return s_liquidityPool;
    }
}
