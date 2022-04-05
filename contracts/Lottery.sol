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
   mapping(Asset => address) assetAdress;

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

   function participate(uint256 ticketsAmount, Asset payMethod) public payable {
      Round storage round = rounds[currentRoundId];
      uint256 allowance = 1 ether; //for test, delete later

      require(
         currentRoundStatus != RoundStatus.completed,
         "Cannot participate, round status is completed"
      );
      uint256 assetToUsd = getPrice(payMethod);
      uint256 totalToPay = assetToUsd * ticketPrice * ticketsAmount;
      require(totalToPay <= allowance || totalToPay <= msg.value, "Token allowance is too low");
      if (payMethod == Asset.ETH) {
         if(totalToPay < msg.value) {
            payable(msg.sender).call{value: msg.value - totalToPay}("");
         }
      } else {
         //transferFrom(msg.sender, totalToPay);
      }
      if (payMethod != round.rewardAsset) {
         totalToPay = swapTokens(payMethod, totalToPay);
      }
      round.funds += totalToPay;

      for (uint256 i = 0; i < ticketsAmount; i++) {
         round.tickets.push(msg.sender);
      }

      participantsFundsByRound[msg.sender][currentRoundId] += totalToPay;
   }

   function withdraw() public {
      if(hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
         for(uint i = 0; i < uint(Asset.ETH); i++) {
            //IERC20(AssetAddress[Asset[i]]).transfer(msg.sender, chargesByAsset[Asset[i]]);
         }
      }

      uint[] memory userFunds = new uint[](4);
      for(uint i = 0; i < rounds.length; i++) {
         if(participantsFundsByRound[msg.sender][i] > 0) {
            userFunds[uint(rounds[i].rewardAsset)] += participantsFundsByRound[msg.sender][i];
            if(msg.sender == rounds[i].winner) {
               userFunds[uint(rounds[i].rewardAsset)] += rounds[i].reward;
            }
         }
      }
   }


   function checkUpkeep(bytes calldata checkdata)
   public
   view
   returns (bool, bytes memory)
   {
      Round storage current = rounds[currentRoundId];

      if(currentRoundStatus == RoundStatus.collecting) {
         if(collectTime + current.startTime < block.timestamp) {
            return (true, abi.encodeWithSignature("investFunds()"));
         }
         return (false,"");
      } else if (currentRoundStatus == RoundStatus.investing) {
         if(collectTime + investTime + current.startTime < block.timestamp) {
            return (true, abi.encodeWithSignature("claimLiquidity()"));
         }
         return (false,"");
      } else {
         if(lotteryResult > 0) {
            return (true, abi.encodeWithSignature("chooseWinner()"));
         }
         return (false,"");
      }
   }

   function performUpkeep(bytes calldata performData) external {
      (bool success, bytes memory result) = address(this).call(performData);
      require(success == true, "function call has failed");
   }

   function getCurrentReward() public {}

   function setPauseStatus(bool _paused) public {
      paused = _paused;
   }

   function swapTokens(Asset from, uint256 amountIn) public returns (uint256) {}

   function investFunds() public {}

   function claimLiquidity() internal {
      Round storage current = rounds[currentRoundId];
      uint total = 1050 * 10**8; // change this for ilendingPool withdraw
      uint liquidity = total - current.funds;

      current.reward = liquidity - liquidity * fee / 100;
   
      generateLotteryNumber();
   }

   function generateLotteryNumber() internal {

      lotteryResult = 1;
   }

   function chooseWinner() internal {
      Round storage current = rounds[currentRoundId];
      current.winner = current.tickets[lotteryResult]; 
   }

   function getPrice(Asset asset) internal returns (uint256) {
      return 100056993;
   }
}
