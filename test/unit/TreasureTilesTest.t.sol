// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { TreasureTiles } from "../../src/TreasureTiles.sol";
import { DeployTreasureTiles } from "../../script/DeployTreasureTiles.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { MockVRFConsumer } from "../mocks/MockVRFConsumer.sol";

contract TreasureTilesTest is Test {
    DeployTreasureTiles deployer;
    HelperConfig config;
    TreasureTiles treasure;
    MockOwner mockOwner;

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant BET_AMOUNT = 1 ether;
    uint256 constant SELECTED_FOUR_TILES = 4;
    uint256 constant SELECTED_SIX_TILES = 6;
    uint256 constant INVALID_TILES = 0;
    uint256 constant INVALID_BET_AMOUNT = 0 ether;
    uint256 constant SERVICE_FEE = 5;
    address PLAYER = makeAddr("player");
    address PLAYERTWO = makeAddr("playertwo");
    address initialOwner;
    address initialOperator;

    event RandomnessRequested(uint64 requestId);
    event RandomnessFulfilled(uint256 indexed nonce, TreasureTiles.Game game);
    event GameStarted(uint256 indexed gameId, uint256 indexed selectedTiles, uint256 indexed betAmount);

    function setUp() public {
        config = new HelperConfig();
        mockOwner = new MockOwner();
        deployer = new DeployTreasureTiles();
        (treasure, config) = deployer.run();

        // Retrieve the active network configuration to get initialOwner and initialOperator
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
        initialOwner = networkConfig.initialOwner;
        initialOperator = networkConfig.initialOperator;

        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYERTWO, STARTING_BALANCE);
        vm.deal(initialOwner, STARTING_BALANCE);
        vm.deal(initialOperator, STARTING_BALANCE);

        // Set the block timestamp for consistency in tests
        vm.warp(1_700_819_134);
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

    function testStartGameTreasureTiles__InvalidTileSelection() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(TreasureTiles.TreasureTiles__InvalidTileSelection.selector);
        treasure.startGame(INVALID_TILES, BET_AMOUNT);
        vm.stopPrank();
    }

    function testStartGameTreasureTiles__BetAmountCantBeZero() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(TreasureTiles.TreasureTiles__BetAmountCantBeZero.selector, INVALID_BET_AMOUNT)
        );
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
        //Logic goes here
    }

    function testCollectFees() public {
        vm.startPrank(initialOwner);
        treasure.transferOwnership(address(mockOwner));
        vm.stopPrank();

        vm.startPrank(address(mockOwner));
        //Logic goes here
        vm.stopPrank();
    }

    function testGetFees() public {
        vm.startPrank(initialOwner);
        treasure.getFees();
        assertEq(treasure.getFees(), 0);
        vm.stopPrank();
    }
}

// MockOwner contract that rejects receiving Ether
contract MockOwner {
    function collectFees(address _treasureTiles) external {
        TreasureTiles(_treasureTiles).collectFees();
    }

    // This contract does not accept Ether
    receive() external payable {
        revert("MockOwner does not accept Ether");
    }
}
