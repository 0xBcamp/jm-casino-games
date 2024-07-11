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
    MockVRFConsumer mockVRFConsumer;

    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant BET_AMOUNT = 1 ether;
    uint256 constant SELECTED_FOUR_TILES = 4;
    uint256 constant SELECTED_SIX_TILES = 6;
    uint256 constant INVALID_TILES = 26;
    uint256 constant INVALID_BET_AMOUNT = 0;
    uint256 constant SERVICE_FEE = 5;
    uint256 gameId = 1;
    address PLAYER = makeAddr("player");
    address PLAYERTWO = makeAddr("playertwo");

    event GameStarted(uint256 indexed gameId, address indexed player, uint256 indexed betAmount);
    event GameOutcome(uint256 indexed gameId, address indexed player, string indexed outcome, uint256 amount);

    function setUp() public {
        config = new HelperConfig();
        deployer = new DeployTreasureTiles();
        mockVRFConsumer = new MockVRFConsumer(address(deployer));
        (treasure, config) = deployer.run();

        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYERTWO, STARTING_BALANCE);
        vm.deal(address(deployer), STARTING_BALANCE);
    }

    modifier PlayerIsPlayingAtTheSameTime() {
        vm.startPrank(PLAYER);
        treasure.startGame{ value: BET_AMOUNT }(SELECTED_FOUR_TILES);
        vm.stopPrank();
        _;
    }

    function testStartGameTreasureTiles__InvalidTileSelection() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(TreasureTiles.TreasureTiles__InvalidTileSelection.selector);
        treasure.startGame{ value: BET_AMOUNT }(INVALID_TILES);
        vm.stopPrank();
    }

    function testStartGameTreasureTiles__BetAmountCantBeZero() public {
        vm.startPrank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(TreasureTiles.TreasureTiles__BetAmountCantBeZero.selector, INVALID_BET_AMOUNT)
        );
        treasure.startGame{ value: INVALID_BET_AMOUNT }(SELECTED_FOUR_TILES);
        vm.stopPrank();
    }

    function testStartGameTreasureTiles__GameAlreadyExists() public PlayerIsPlayingAtTheSameTime {
        vm.startPrank(PLAYER);
        vm.expectRevert(TreasureTiles.TreasureTiles__GameAlreadyExists.selector);
        treasure.startGame{ value: BET_AMOUNT }(SELECTED_FOUR_TILES);
        vm.stopPrank();
    }

    function test_ExpectEmit_EventGameStarted() public {
        vm.startPrank(PLAYER);
        vm.expectEmit(true, true, true, false);
        emit GameStarted(gameId, PLAYER, BET_AMOUNT);
        treasure.startGame{ value: BET_AMOUNT }(SELECTED_FOUR_TILES);
        vm.stopPrank();
    }

    function testStartGame() public {
        // vm.startPrank(PLAYER);
        // treasure.startGame{ value: BET_AMOUNT }(SELECTED_FOUR_TILES);
        // bytes memory extraData = abi.encode(SELECTED_FOUR_TILES, BET_AMOUNT, gameId);
        // uint256 requestId = mockVRFConsumer.requestRandomness(extraData);
        // uint256 mockRandomness = 123;
        // mockVRFConsumer.testFulfillRandomness(mockRandomness, requestId, extraData);
        // vm.expectRevert(TreasureTiles.TreasureTiles__GameAlreadyExists.selector);
        // vm.stopPrank();
    }

    function testCollectFeesTreasureTiles__NoFeesToCollect() public { }

    function testCollectionFeesTreasureTiles__FailedToCollectFees() public { }

    function testCollectFees() public { }

    function testGetFees() public {
        vm.startPrank(address(deployer));
        treasure.getFees();
        assertEq(treasure.getFees(), 0);

        vm.expectRevert(TreasureTiles.TreasureTiles__NoFeesToCollect.selector);
        treasure.collectFees();
        vm.stopPrank();
    }
}
