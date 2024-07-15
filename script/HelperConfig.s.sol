// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        address initialOwner;
        address initialOperator;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;

    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;

    uint256 constant POLYGON_MAINNET_CHAIN_ID = 137;
    uint256 constant POLYGON_MUMBAI_CHAIN_ID = 80_001;

    uint256 constant MODE_MAINNET_CHAIN_ID = 34_443;
    uint256 constant MODE_SEPOLIA_CHAIN_ID = 919;

    // Local network state variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_MAINNET_CHAIN_ID] = getZkSyncConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
        networkConfigs[POLYGON_MAINNET_CHAIN_ID] = getPolygonMainnetConfig();
        networkConfigs[POLYGON_MUMBAI_CHAIN_ID] = getPolygonMumbaiConfig();
        networkConfigs[MODE_MAINNET_CHAIN_ID] = getModeMainnetConfig();
        networkConfigs[MODE_SEPOLIA_CHAIN_ID] = getModeSepoliaConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].initialOwner != address(0)) {
            return networkConfigs[chainId];
        } else {
            return getOrCreateAnvilEthConfig();
        }
    }

    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getEthMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getEthSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getZkSyncConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getZkSyncSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getPolygonMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getPolygonMumbaiConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getModeMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    function getModeSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
    }

    /*//////////////////////////////////////////////////////////////
                              LOCAL CONFIG
    //////////////////////////////////////////////////////////////*/
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.initialOwner != address(0)) {
            return localNetworkConfig;
        }
        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");

        _deployMocks();

        localNetworkConfig = NetworkConfig({ initialOwner: address(msg.sender), initialOperator: address(0x1) });
        return localNetworkConfig;
    }

    /*
     * Add your mocks, deploy and return them here for your local anvil network
     */
    function _deployMocks() internal { }
}
