// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test, console2} from "forge-std/Test.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";
import {PredictionPoolPrize} from "../src/PredictionPoolPrize.sol";

contract PredictionPoolTest is Test {
    PredictionPoolPrize predictionPool;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        predictionPool = deployFundMe.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testMinumimValue() public {
        uint256 minimumValue = 0.01 ether;
        assertEq(predictionPool.ENTRANCE_FEE(), minimumValue);
    }

    function testVersion() public {
        uint256 version = predictionPool.version();
        assertEq(version, 4);
    }

    function testNumberOfPlayers() public {
        uint256 numberOfPlayers = predictionPool.getTotalPlayers();
        assertEq(numberOfPlayers, 0);
    }

    function testEntranceFeeAndGetEthPrice() public {
        vm.prank(PLAYER);
        predictionPool.enterPredictionPool{value: 0.01 ether}();
        uint256 numberOfPlayers = predictionPool.getTotalPlayers();
        int ethPrice = predictionPool.getEthPrice();
        console2.logInt(ethPrice);

        assertEq(numberOfPlayers, 1);
    }
}
