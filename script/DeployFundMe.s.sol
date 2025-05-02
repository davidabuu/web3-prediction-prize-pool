// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {PredictionPoolPrize} from "../src/PredictionPoolPrize.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployFundMe is Script {
    function run() external returns (PredictionPoolPrize) {
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        (
            address priceFeedAddress,
            address vrfCoordinator,
            bytes32 gasLane,
            uint32 callbackGasLimit,
            uint64 subscriptionId,
            uint256 interval
        ) = helperConfig.activeNetworkConfig();
        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subscriptionId, vrfCoordinatorV2) = createSubscription
                .createSubscription(vrfCoordinatorV2, account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatorV2,
                subscriptionId,
                link,
                account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast();
        PredictionPoolPrize predictionPoolPrize = new PredictionPoolPrize(
            priceFeedAddress,
            subscriptionId,
            gasLane,
            interval,
            callbackGasLimit,
            vrfCoordinator
        );
        vm.stopBroadcast();
        addConsumer.addConsumer(
            address(predictionPoolPrize),
            vrfCoordinatorV2,
            config.subscriptionId,
            config.account
        );
        return predictionPoolPrize;
    }
}
