// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { TreasureTiles } from "../src/TreasureTiles.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";

contract DeployTreasureTiles is Script {
    function run() external returns (TreasureTiles, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        TreasureTiles treasure = new TreasureTiles(config.operator, config.initialOwner);

        return (treasure, helperConfig);
    }
}
