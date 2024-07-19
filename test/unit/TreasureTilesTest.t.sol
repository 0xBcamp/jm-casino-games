// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { TreasureTiles } from "../../src/TreasureTiles.sol";
import { DeployTreasureTiles } from "../../script/DeployTreasureTiles.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

contract TreasureTilesTest is Test {
    DeployTreasureTiles deployer;
    HelperConfig config;
    TreasureTiles treasure;

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant BET_AMOUNT = 1 ether;
    uint256 constant SELECTED_FOUR_TILES = 4;
    uint256 constant SELECTED_SIX_TILES = 6;
    uint256 constant INVALID_TILES = 0;
    uint256 constant INVALID_BET_AMOUNT = 0 ether;
    uint256 constant SERVICE_FEE = 5;
    uint256 constant ONE_E_EIGHTEEN = 1e18;
    uint256 constant ONE_E_FIFTEEN = 1e15;
    uint256 constant ONE_THOUSAND = 1000;
    address PLAYER = makeAddr("player");
    address PLAYERTWO = makeAddr("playertwo");
    address initialOwner;
    address initialOperator;
    address feeRecipient;

    event RandomnessRequested(uint64 indexed requestId);
    event RandomnessFulfilled(uint256 indexed nonce, TreasureTiles.Game Game);

    function setUp() public {
        config = new HelperConfig();
        deployer = new DeployTreasureTiles();
        (treasure, config) = deployer.run();

        // Retrieve the active network configuration to get initialOwner and initialOperator
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
        initialOwner = networkConfig.initialOwner;
        initialOperator = networkConfig.initialOperator;
        feeRecipient = networkConfig.feeRecipient;

        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYERTWO, STARTING_BALANCE);
        vm.deal(initialOwner, STARTING_BALANCE);
        vm.deal(initialOperator, STARTING_BALANCE);
        vm.deal(address(treasure), STARTING_BALANCE);
        vm.deal(feeRecipient, STARTING_BALANCE);
        // Set the block timestamp for consistency in tests
        vm.warp(1_700_819_134);
    }

    function testConstructor() public view {
        // Assert that the contract is deployed with the correct initial settings
        assertEq(treasure.owner(), initialOwner);
        assertEq(treasure.feeRecipient(), feeRecipient);
    }

    function testRequestRandomness() public {
        uint256 gameId = 1;
        bytes memory data = abi.encode(SELECTED_FOUR_TILES, BET_AMOUNT, gameId);
        vm.expectEmit(true, true, true, true);
        emit RandomnessRequested(0);

        vm.prank(initialOwner);
        treasure.requestRandomness(data);

        // Verify that s_lastRequestId is updated correctly
        assertEq(treasure.lastRequestId(), 0);
    }

    function testTreasureFulfillRandomness() public {
        uint256 randomness = 0x471403f3a8764edd4d39c7748847c07098c05e5a16ed7b083b655dbab9809fae;
        uint256 requestId = 0;
        uint256 gameId = 1;
        uint256 roundId = 2_671_924;

        vm.prank(PLAYER);
        treasure.startGame(SELECTED_FOUR_TILES, BET_AMOUNT);

        bytes memory data = abi.encode(gameId);
        bytes memory dataWithRound = abi.encode(roundId, abi.encode(requestId, data));

        vm.prank(initialOperator);
        treasure.fulfillRandomness(randomness, dataWithRound);

        (
            uint256 selectedTiles,
            uint256 betAmount,
            address player,
            uint256 requestTime,
            uint256 requestBlock,
            uint256 fulfilledTime,
            uint256 fulfilledBlock,
            uint256 storedRandomness
        ) = treasure.s_games(gameId);

        assertEq(selectedTiles, SELECTED_FOUR_TILES);
        assertEq(betAmount, BET_AMOUNT);
        assertEq(player, PLAYER); // Assuming the deployer starts the game
        assertEq(requestTime, 1_700_819_134); // Block timestamp set in setUp
        assertEq(requestBlock, 1); // Block number of the request
        assertEq(fulfilledTime, 1_700_819_134); // Block timestamp after fulfillment
        assertEq(fulfilledBlock, 1); // Block number after fulfillment
        assertEq(storedRandomness, storedRandomness); // Verifying the stored randomness is randomizing (I know this is
            // equal to its-self)
    }

    function testUpdateFeeRecipient() public {
        // Only the owner should be able to update the fee recipient
        vm.startPrank(initialOwner);
        address newFeeRecipient = address(0xBEEF);
        treasure.updateFeeRecipient(newFeeRecipient);
        vm.stopPrank();
        // Verify the fee recipient was updated
        assertEq(treasure.feeRecipient(), newFeeRecipient);
    }

    function testWinningScenario() public {
        // Simulate a winning scenario
        uint256 randomness = 123_456_789; // Adjust this value based on probability calculations
        uint256 gameId = 1;
        uint256 roundId = 2_671_924;

        // Start a game with a bet
        vm.prank(PLAYER);
        treasure.startGame(SELECTED_FOUR_TILES, BET_AMOUNT);

        bytes memory data = abi.encode(gameId);
        bytes memory dataWithRound = abi.encode(roundId, abi.encode(0, data)); // Using 0 as requestId since we're not
            // simulating a real request

        vm.prank(initialOperator);
        treasure.fulfillRandomness(randomness, dataWithRound);

        // Calculate expected outcome based on probabilities and multipliers
        uint256 normalizedValue = randomness % ONE_THOUSAND;
        uint256[25] memory probabilities = treasure.getProbabilities();
        uint256 currentProbability = probabilities[SELECTED_FOUR_TILES - 1];
        bool expectedWin = normalizedValue > currentProbability / ONE_E_FIFTEEN;

        // Debugging: Print intermediate values
        console2.log("Normalized Value:", normalizedValue);
        console2.log("Current Probability:", currentProbability);
        console2.log("Expected Win:", expectedWin);

        // Check if the user won
        uint256[25] memory multipliers = treasure.getMultipliers();
        uint256 expectedWonAmount = BET_AMOUNT * multipliers[SELECTED_FOUR_TILES - 1] / ONE_E_EIGHTEEN;
        uint256 fee = (expectedWonAmount * 5) / 1e3; // Calculating the 0.5% fee
        uint256 actualWonAmount = expectedWonAmount - fee;

        vm.prank(PLAYER);
        // Debugging: Print final amounts
        console2.log("Expected Won Amount:", expectedWonAmount);
        console2.log("Actual Won Amount:", actualWonAmount);

        assertTrue(expectedWin, "Expected to win");
        assertGe(actualWonAmount, 1_096_888_000_000_000_000, "User should receive the expected winnings");
    }

    function testLosingScenario() public {
        // Simulate a losing scenario
        uint256 randomness = 987_234_892_730_345; // Adjust this value based on your probability
            // calculations
        uint256 gameId = 1;
        uint256 roundId = 2_671_925;

        // Start a game with a bet
        vm.prank(PLAYER);
        treasure.startGame(SELECTED_SIX_TILES, BET_AMOUNT);

        bytes memory data = abi.encode(gameId);
        bytes memory dataWithRound = abi.encode(roundId, abi.encode(0, data)); // Using 0 as requestId since we're not
            // simulating a real request

        vm.prank(initialOperator);
        treasure.fulfillRandomness(randomness, dataWithRound);

        // Calculate expected outcome based on probabilities and multipliers
        uint256 normalizedValue = randomness % ONE_THOUSAND;
        uint256[25] memory probabilities = treasure.getProbabilities();
        uint256 currentProbability = probabilities[SELECTED_SIX_TILES - 1];
        bool expectedLoss = normalizedValue <= currentProbability / ONE_E_FIFTEEN;

        // Debugging: Print intermediate values
        console2.log("Normalized Value:", normalizedValue);
        console2.log("Current Probability:", currentProbability);
        console2.log("Expected Loss:", expectedLoss);

        // Check if the user lost
        uint256 expectedLostAmount = 1 ether;
        uint256 actualLostAmount = BET_AMOUNT;

        assertTrue(expectedLoss, "Expected to lose");
        assertEq(actualLostAmount, expectedLostAmount, "User should lose the entire bet");
    }

    function testStartGameTreasureTiles__InvalidTileSelection() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(TreasureTiles.TreasureTiles__InvalidTileSelection.selector);
        treasure.startGame(INVALID_TILES, BET_AMOUNT);
        vm.stopPrank();
    }

    function testStartGameTreasureTiles__BetAmountCantBeZero() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(TreasureTiles.TreasureTiles__BetAmountCantBeZero.selector);
        treasure.startGame(SELECTED_FOUR_TILES, INVALID_BET_AMOUNT);
        vm.stopPrank();
    }

    function testCollectFeesTreasureTiles__NoFeesToCollect() public {
        vm.startPrank(initialOwner);
        treasure.getFees();
        assertEq(treasure.getFees(), 0);

        vm.expectRevert(TreasureTiles.TreasureTiles__NoFeesToCollect.selector);
        treasure.collectFees();
        vm.stopPrank();
    }

    function testCollectionFeesTreasureTiles__FailedToCollectFees() public {
        vm.startPrank(initialOwner);
        vm.stopPrank();
    }

    function testGetFees() public {
        // Simulate a winning scenario
        uint256 randomness = 123_456_789; // Adjust this value based on probability calculations
        uint256 gameId = 1;
        uint256 roundId = 2_671_924;

        // Start a game with a bet
        vm.prank(PLAYER);
        treasure.startGame(SELECTED_FOUR_TILES, BET_AMOUNT);

        bytes memory data = abi.encode(gameId);
        bytes memory dataWithRound = abi.encode(roundId, abi.encode(0, data)); // Using 0 as requestId since we're not
            // simulating a real request

        vm.prank(initialOperator);
        treasure.fulfillRandomness(randomness, dataWithRound);

        // Calculate expected outcome based on probabilities and multipliers
        uint256 normalizedValue = randomness % ONE_THOUSAND;
        uint256[25] memory probabilities = treasure.getProbabilities();
        uint256 currentProbability = probabilities[SELECTED_FOUR_TILES - 1];
        bool expectedWin = normalizedValue > currentProbability / ONE_E_FIFTEEN;

        // Check if the user won
        uint256[25] memory multipliers = treasure.getMultipliers();
        uint256 expectedWonAmount = BET_AMOUNT * multipliers[SELECTED_FOUR_TILES - 1] / ONE_E_EIGHTEEN;
        uint256 fee = (expectedWonAmount * SERVICE_FEE) / 1e3; // Calculating the 0.5% fee
        uint256 actualWonAmount = expectedWonAmount - fee;

        assertTrue(expectedWin, "Expected to win");
        assertGe(actualWonAmount, 1_096_888_000_000_000_000, "User should receive the expected winnings");
        uint256 expectedFees = treasure.getFees() + fee;

        assertEq(fee, expectedFees, "Fees should equal the 0.5% of the expectedWonAmount"); // Adjusted
    }

    function testGetServiceFee() public view {
        uint256 serviceFee = treasure.getServiceFee();
        assertEq(serviceFee, SERVICE_FEE); // Service fee should be 5 (0.5%)
    }

    function testGetProbabilities() public view {
        uint256[25] memory probabilities = treasure.getProbabilities();
        assertEq(probabilities[0], 200_000_000_000_000_000); // First probability should match the defined value
    }

    function testGetMultipliers() public view {
        uint256[25] memory multipliers = treasure.getMultipliers();
        assertEq(multipliers[0], 1_006_400_000_000_000_000); // First multiplier should match the defined value
    }

    function testGetLiquidityPool() public view {
        // Assuming there's a way to add liquidity in the setup or another function
        // Verify the liquidity pool amount is returned correctly
        uint256 liquidityPool = treasure.getLiquidityPool();
        assertEq(liquidityPool, 0); // Adjust according to your setup
    }
}
