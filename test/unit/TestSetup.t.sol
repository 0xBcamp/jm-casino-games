// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { TreasureTiles } from "../../src/TreasureTiles.sol";

contract TestSetup is Test {
    TreasureTiles treasure;

    address initialOwner = makeAddr("initialOwner");

    function setUp() public {
        treasure = new TreasureTiles(initialOwner);
    }

    function test() public { }
}
