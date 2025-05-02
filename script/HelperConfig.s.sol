// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {LinkToken} from "../test/mock/LinkToken.sol";
import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether; // 0.25 LINK per request
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 1 GWEI
     uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        address priceFeedAddress;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint64 subscriptionId;
        uint256 interval;
        address link;
        address account;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 18;
    int256 public constant INITIAL_PRICE = 2000e18;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            interval: 30,
             account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D,
               link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (
            activeNetworkConfig.priceFeedAddress != address(0) &&
            activeNetworkConfig.vrfCoordinator != address(0)
        ) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        // Deploy mocks
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );

        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK
        );
          LinkToken link = new LinkToken();
        uint256 subscriptionId = vRFCoordinatorV2Mock.createSubscription();
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            priceFeedAddress: address(mockV3Aggregator),
            vrfCoordinator: address(vRFCoordinatorV2Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            interval: 30,
             account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D,
             link:address(link)
        });

        return activeNetworkConfig;
    }
}
