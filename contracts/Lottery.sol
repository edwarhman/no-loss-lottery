pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IStableSwapPool.sol";
import "hardhat/console.sol";
import "./VRFv2Consumer.sol";

///@title No loss lottery
///@author Emerson Warhman
///@notice A lottery where you can participate every week without loss your money
contract Lottery is Initializable, AccessControlUpgradeable {
   ///@notice amount of time the lottery is recollecting funds for the current round
   uint256 public collectTime;
   ///@notice amount of time the funds are in the lending pool
   ///@notice users that invest while the current round funds are in the pool will
   ///@notice participate in the next round
   uint256 public investTime;
   ///@notice ID of the current round
   uint256 public currentRoundId;
   ///@notice current round status (collecting, investing, finished)
   RoundStatus public currentRoundStatus;
   ///@notice price of each lottery ticket (in USD)
   uint256 public ticketPrice;
   ///@notice actual total of fee charges by the contract
   mapping(Asset => uint256) public chargesByAsset;
   ///@notice winnig ticket number of the last finished round
   uint256 public winningTicket;
   ///@notice indicate if the lottery contract is paused
   bool public paused;
   ///@notice collection of all rounds
   Round[] public rounds;
   ///@notice current fee price the contract charges from rewards
   uint256 public fee;
   ///@notice contract in charge of get the random winner number from descentralized providers
   VRFv2Consumer public vrf2Consumer;
   ///@notice address of each asset users can use to participate
   mapping(Asset => address) public tokenAddress;
   ///@notice decimals of each token
   mapping(Asset => uint256) public tokenDecimals;
   ///@notice lending pool address where rounds found will be invested
   address public lendingPoolAddress;
   ///@notice swapper used to swap stable coins
   address public stableSwapAddress;

   mapping(Asset => int128) assetToInt128;
   ///@notice structure of each lottery round
   ///@param startTime time when round started
   ///@param funds totals funds collected
   ///@param winner winner address ( address 0 indicates there is not winner yet)
   ///@param rewardAsset asset which participant will receive when the claim their money
   ///@param tickets collections of tickets purchased for the lottery
   ///@param participantFunds funds invested for each participant
   struct Round {
      uint256 startTime;
      uint256 funds;
      address winner;
      Asset rewardAsset;
      uint256 reward;
      address[] tickets;
      mapping(address => uint256) participantFunds;
   }

   ///@notice current round status
   enum RoundStatus {
      collecting,
      investing,
      finished
   }

   ///@notice assets used in the lottery
   enum Asset {
      DAI,
      USDC,
      USDT,
      ETH
   }

   ///@notice contract initializer
   ///@param _consumer ramdom number getter
   ///@param tokens tokens addresses
   ///@param decimals tokens decimals
   ///@param _lendingPoolAddress lending pool address
   ///@param _stableSwapAddress stable swapper address
   function initialize(
      VRFv2Consumer _consumer,
      address[] memory tokens,
      uint256[] memory decimals,
      address _lendingPoolAddress,
      address _stableSwapAddress
   ) public initializer {
      collectTime = 2 days;
      investTime = 5 days;
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

      vrf2Consumer = _consumer;
      int128 j = 0;
      for (uint256 i = 0; i < tokens.length; i++) {
         tokenAddress[Asset(i)] = tokens[i];
         tokenDecimals[Asset(i)] = decimals[i];
         assetToInt128[Asset(i)] = j;
         j++;
      }

      lendingPoolAddress = _lendingPoolAddress;
      stableSwapAddress = _stableSwapAddress;

      // initialize new current round and the next one
      rounds.push();
      rounds[0].startTime = block.timestamp;
      rounds[0].rewardAsset = Asset.USDC;
      rounds[0].tickets.push(address(0));

      currentRoundStatus = RoundStatus.collecting;

      rounds.push();
      rounds[1].rewardAsset = Asset.USDC;
      rounds[1].tickets.push(address(0));

      ticketPrice = 10; //10 usd
   }

   ///@notice Allow the user participate in the current round
   ///@notice if the current round status is investing, allows
   ///@notice to participate in the next round
   ///@param ticketsAmount amount of tickets to buy
   ///@param payMethod asset the participant will use to pay the tickets
   function participate(uint256 ticketsAmount, Asset payMethod)
      public
      payable
   {
      Round storage round = rounds[
         currentRoundStatus == RoundStatus.collecting
            ? currentRoundId
            : currentRoundId + 1
      ];

      uint256 allowance = 1 ether; //for test, delete later

      require(
         currentRoundStatus != RoundStatus.finished,
         "Cannot participate, round status is finished"
      );
      uint256 assetToUsd = getPrice(payMethod);
      uint256 totalToPay = assetToUsd * ticketPrice * ticketsAmount;
      require(
         (totalToPay <= allowance && payMethod != Asset.ETH) ||
            totalToPay <= msg.value,
         "Token allowance is too low"
      );
      if (payMethod == Asset.ETH) {
         if (totalToPay < msg.value) {
            (bool success, ) = payable(msg.sender).call{
               value: msg.value - totalToPay
            }("");
            require(success, "refund has failed");
         }
      } else {
         //transferFrom(msg.sender, totalToPay);
      }
      if (payMethod != round.rewardAsset) {
         totalToPay = _swapTokens(
            payMethod,
            round.rewardAsset,
            totalToPay
         );
      }

      round.funds += totalToPay;

      for (uint256 i = 0; i < ticketsAmount; i++) {
         round.tickets.push(msg.sender);
      }

      round.participantFunds[msg.sender] += totalToPay;
   }

   ///@notice allow the user withdraw the funds he has invested in all the past rounds
   ///@notice if user has won he will receive too his rewards
   function withdraw() public {
      if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
         for (uint256 i = 0; i < uint256(Asset.ETH); i++) {
            //IERC20(AssetAddress[Asset[i]]).transfer(msg.sender, chargesByAsset[Asset[i]]);
         }
      }

      uint256[] memory userFunds = new uint256[](4);
      for (uint256 i = 0; i < rounds.length; i++) {
         if (rounds[i].participantFunds[msg.sender] > 0) {
            userFunds[uint256(rounds[i].rewardAsset)] += rounds[i]
               .participantFunds[msg.sender];
            if (msg.sender == rounds[i].winner) {
               userFunds[uint256(rounds[i].rewardAsset)] += rounds[i]
                  .reward;
            }
         }
      }
   }

   ///@notice used to check if is necessary to make changes in the lottery
   function checkUpkeep(
      bytes calldata /*checkdata*/
   ) public view returns (bool, bytes memory) {
      Round storage current = rounds[currentRoundId];
      if (
         currentRoundStatus == RoundStatus.collecting &&
         collectTime + current.startTime <= block.timestamp
      ) {
         return (true, "");
      } else if (
         currentRoundStatus == RoundStatus.investing &&
         collectTime + investTime + current.startTime <=
         block.timestamp
      ) {
         return (true, "");
      } else if (winningTicket > 0) {
         return (true, "");
      }
      return (false, "");
   }

   ///@notice necessary perform a change in the lottery if necessary
   function performUpkeep(
      bytes calldata /*performData*/
   ) external {
      Round storage current = rounds[currentRoundId];

      if (
         currentRoundStatus == RoundStatus.collecting &&
         collectTime + current.startTime <= block.timestamp
      ) {
         investFunds();
      } else if (
         currentRoundStatus == RoundStatus.investing &&
         collectTime + investTime + current.startTime <=
         block.timestamp
      ) {
         _finishRound();
      } else if (
         currentRoundStatus == RoundStatus.finished &&
         winningTicket > 0
      ) {
         _setWinner();
         _startNextRound();
      }
   }

   function getCurrentReward() public {}

   ///@notice set the paused status
   function setPauseStatus(bool _paused) public {
      paused = _paused;
   }

   function _swapTokens(
      Asset from,
      Asset to,
      uint256 amountIn
   ) internal returns (uint256) {
      uint256 expected;
      uint256 prev;
      uint256 received;
      if (from == Asset.ETH) {
         received = amountIn;
      } else {
         prev = IERC20(tokenAddress[to]).balanceOf(address(this));
         IERC20(tokenAddress[from]).approve(
            stableSwapAddress,
            amountIn
         );
         expected = IStableSwapPool(stableSwapAddress).get_dy(
            assetToInt128[from],
            assetToInt128[to],
            amountIn
         );
         IStableSwapPool(stableSwapAddress).exchange(
            assetToInt128[from],
            assetToInt128[to],
            amountIn,
            (expected * 99) / 100
         );

         received =
            IERC20(tokenAddress[to]).balanceOf(address(this)) -
            prev;
      }
      return received;
   }

   function investFunds() public {
      Round storage current = rounds[currentRoundId];
      Asset asset = current.rewardAsset;

      currentRoundStatus = RoundStatus.investing;
      IERC20(tokenAddress[asset]).approve(
         lendingPoolAddress,
         current.funds
      );
      ILendingPool(lendingPoolAddress).deposit(
         tokenAddress[asset],
         current.funds,
         address(this),
         0
      );
   }

   function claimLiquidity() internal {
      Round storage current = rounds[currentRoundId];
      Asset asset = current.rewardAsset;
      uint256 maxUint = 2**256 - 1;
      uint256 total;
      (uint256 totalCollateral, , , , , ) = ILendingPool(
         lendingPoolAddress
      ).getUserAccountData(address(this));
      total = ILendingPool(lendingPoolAddress).withdraw(
         tokenAddress[asset],
         maxUint,
         address(this)
      ); // need to add total assignment
      uint256 liquidity = total - current.funds;

      current.reward = liquidity - (liquidity * fee) / 100;
   }

   function generateLotteryNumber() internal {
      winningTicket = 100000000;

      vrf2Consumer.requestRandomWords(
         rounds[currentRoundId].tickets.length
      );
   }

   function _finishRound() internal {
      claimLiquidity();
      generateLotteryNumber();

      currentRoundStatus = RoundStatus.finished;
   }

   function _startNextRound() internal {
      currentRoundStatus = RoundStatus.collecting;
   }

   function _setWinner() internal {
      Round storage current = rounds[currentRoundId];
      //current.winner = current.tickets[winningTicket];
   }

   function getPrice(Asset asset) internal returns (uint256) {
      return asset == Asset.ETH ? 27 * 10**6 : 1056993;
   }

   function getTicketOwner(uint256 ticket)
      public
      view
      returns (address)
   {
      require(
         ticket < rounds[currentRoundId].tickets.length,
         "Specified ticket not found"
      );
      return rounds[currentRoundId].tickets[ticket];
   }

   function getParticipantFunds(uint256 roundId)
      public
      view
      returns (uint256)
   {
      require(roundId < rounds.length, "Specified round not found");
      return rounds[roundId].participantFunds[msg.sender];
   }

   function setVrfConsumer(VRFv2Consumer _consumer) public {
      vrf2Consumer = _consumer;
   }

   function setWinningTicket(uint256 _winner) public {
      require(
         msg.sender == address(vrf2Consumer),
         "tx sender is not the allowed vrf consumer"
      );
      winningTicket = _winner;
   }
}
