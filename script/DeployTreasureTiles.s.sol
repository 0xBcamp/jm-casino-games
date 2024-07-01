// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { TreasureTiles } from "../src/TreasureTiles.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";

contract DeployTreasureTiles is Script {
    HelperConfig helperConfig;

    constructor(address helperConfigAddress) {
        helperConfig = HelperConfig(helperConfigAddress);
    }

    function run() external returns (TreasureTiles) {
        //HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        //If we use ownable or access control parameter needed would be (config.initialOwner)
        TreasureTiles treasure = new TreasureTiles();

        return treasure;
    }

    function getHelperConfig() external view returns (HelperConfig) {
        return helperConfig;
    }
}
