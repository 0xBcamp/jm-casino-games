// SPDX-License-Identifier: MIT

import { Test, console2 } from "forge-std/Test.sol";
import { TreasureTiles } from "../../src/TreasureTiles.sol";
import { DeployTreasureTiles } from "../../script/DeployTreasureTiles.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

pragma solidity 0.8.24;

contract TreasureTilesTest is Test {
    DeployTreasureTiles deployer;
    HelperConfig helperConfig;
    TreasureTiles treasure;

    uint256 constant STARTING_BALANCE = 1000;
    address PLAYER = makeAddr("player");
    address PLAYERTWO = makeAddr("player");

    function setUp() public {
        helperConfig = new HelperConfig();

        //If we use ownable or access control parameter needed would be (address(config))
        deployer = new DeployTreasureTiles(address(this));
        treasure = deployer.run();

        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYERTWO, STARTING_BALANCE);
    }

    function test() public { }
}
