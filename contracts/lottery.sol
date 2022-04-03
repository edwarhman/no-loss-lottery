pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Lottery is Initializable, AccessControlUpgradeable {
   uint256 public collectTime = 2;
   uint256 public investTime = 5;

   uint256 public currentRoundId;
   RoundStatus public currentRoundStatus;
   uint256 public ticketPrice;
   mapping(Asset => uint256) public chargesByAsset;
   uint256 public lotteryResult;
   bool public paused;
   Round[] public rounds;
   mapping(address => mapping(uint256 => uint256)) public participantsFundsByRound;
   uint256 public fee;

   struct Round {
      uint256 startTime;
      address[] tickets;
      uint256 funds;
      address winner;
      Asset rewardAsset;
      uint256 reward;
   }

   enum RoundStatus {
      collecting,
      investing,
      completed
   }

   enum Asset {
      DAI,
      USDC,
      USDT,
      ETH
   }

   function initialize() public initializer {
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
   }

   function participate(uint256 ticketsAmount, Asset payMethod) public {
      Round storage round = rounds[currentRoundId];
      uint256 allowance = 1 ether; //for test, delete later

      require(
         currentRoundStatus != RoundStatus.completed,
         "Cannot participate, round status is completed"
      );
      uint256 assetToUsd = getPrice(payMethod);
      uint256 totalToPay = assetToUsd * ticketPrice * ticketsAmount;
      require(totalToPay <= allowance, "Token allowance is too low");
      //transferFrom(msg.sender, totalToPay);
      if (payMethod != round.rewardAsset) {
         totalToPay = swapTokens(payMethod, totalToPay);
      }
      round.funds += totalToPay;

      for (uint256 i = 0; i < ticketsAmount; i++) {
         round.tickets.push(msg.sender);
      }
   }

   function withdraw() public {}

   function checkUpkeep(bytes calldata checkdata)
      public
      view
      returns (bool, bytes memory)
   {}

   function performUpkeep(bytes calldata performData) external {}

   function getCurrentReward() public {}

   function setPauseStatus(bool _paused) public {
      paused = _paused;
   }

   function swapTokens(Asset from, uint256 amountIn) public returns (uint256) {}

   function investFunds() public {}

   function claimLiquidity() internal {}

   function chooseWinner() internal {}

   function getPrice(Asset asset) internal returns (uint256) {
      return 100056993;
   }
}
