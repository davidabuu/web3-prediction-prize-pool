// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A Prediction Pool Prize to determine prize of ETH
 * @author Abu David
 * @notice This contract is for creating a prediction pool prize for ETH
 * @dev This implements the Chainlink VRF, Chainlink Data Feeds, and Chainlink Automation
 */
contract PredictionPoolPrize is VRFConsumerBaseV2Plus {
    /*Errors*/
    error PredictionPoolPrize__NotEnoughETH();
    error PredictionPoolPrize__TranferFailed();
    error PredictionPrizePool__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    enum PredictionPoolPrizeState {
        OPEN,
        CALCULATING
    }

    uint256 public constant version = 4;
    /*State Variable */
    address payable[] public s_players;
    address payable[] public s_correctGuessers;
    mapping(address => bool) private s_hasGuessedCorrectly;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    PredictionPoolPrizeState private s_predictionPrizeState;

    uint256 public constant ENTRANCE_FEE = 0.01 ether;
    AggregatorV3Interface private s_priceFeedAddress;
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    /*Events*/
    event PlayersEntered(address indexed players);
    event WinnerPicked(address indexed winner);

    constructor(
        address priceFeedAddress,
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_gasLane = gasLane;

        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        s_priceFeedAddress = AggregatorV3Interface(priceFeedAddress);
    }

    //Get The Price Feed for ETH Chainlink Price Feeds
    //Enter The pool price and Pay
    function enterPredictionPool() public payable {
        if (msg.value < ENTRANCE_FEE) {
            revert PredictionPoolPrize__NotEnoughETH();
        }
        s_players.push(payable(msg.sender));
        emit PlayersEntered(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = PredictionPoolPrizeState.OPEN == s_predictionPrizeState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */) external  {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert PredictionPrizePool__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_predictionPrizeState)
            );
        }

        s_predictionPrizeState = PredictionPoolPrizeState.CALCULATING;

        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    //Get the Price of ETH
    function getEthPrice() public view returns (int) {
        (, int256 answer, , , ) = AggregatorV3Interface(s_priceFeedAddress)
            .latestRoundData();
        int256 amountInUsd = answer / 1000000000000000000;
        return amountInUsd;
    }

    //Correct Guessers Rewards
    function guessEthPrice(int256 guessEthPrice) public {
        int256 ethPrice = getEthPrice();
        if (guessEthPrice == ethPrice && !s_hasGuessedCorrectly[msg.sender]) {
            s_correctGuessers.push(payable(msg.sender));
            s_hasGuessedCorrectly[msg.sender] = true;
        }
    }

    //Perform Chainlink VRF
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 winnderIndex = randomWords[0] % s_correctGuessers.length;
        address payable winner = s_correctGuessers[winnderIndex];
        s_players = new address payable[](0);
        s_correctGuessers = new address payable[](0);
        (bool success, ) = winner.call{value: address(this).balance}("");
        emit WinnerPicked(winner);
        s_predictionPrizeState = PredictionPoolPrizeState.OPEN;
        if (!success) {
            revert PredictionPoolPrize__TranferFailed();
        }
    }

    function getTotalPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getPredictionPrizeState()
        public
        view
        returns (PredictionPoolPrizeState)
    {
        return s_predictionPrizeState;
    }
}
