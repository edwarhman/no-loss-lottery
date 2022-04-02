pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Lottery is Initializable, AccessControlUpgradeable {
	uint COLLECT_TIME = 2;
	uint INVEST_TIME = 5;

	uint public currentRoundId;
	RoundStatus public currentRoundStatus;
	uint public ticketPrice;
	mapping(Asset => uint) chargesByAsset;
	uint LotteryResult;
	bool public paused;
	Round[] public rounds;
	mapping(address => mapping(uint => uint)) participantsFundsByRound;
	uint public fee;

	struct Round {
		uint startTime;
		address[] tickets;
		uint funds;
		address winner;
		Asset rewardAsset;
		uint reward;
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

	function participate(uint ticketsAmount, Asset payMethod) public	{
		Round storage round = rounds[currentRoundId];
		uint allowance = 1 ether; //for test, delete later
	
		require(currentRoundStatus != RoundStatus.completed, "Cannot participate when round status is completed");
		uint assetToUsd = getPrice(payMethod);
		uint totalToPay = assetToUsd * ticketPrice * ticketsAmount; 
		require(totalToPay > allowance);
		//transferFrom(msg.sender, totalToPay);
		if(payMethod != round.rewardAsset) {
			totalToPay = swapTokens(payMethod, totalToPay);
		}
		round.funds += totalToPay;

		for(uint i = 0; i < ticketsAmount; i++) {
			round.tickets.push(msg.sender);
		}
	}

	function withdraw() public {

	}

	function checkUpkeep(bytes calldata checkdata) public view returns(bool, bytes memory) {

	}

	function performUpkeep(bytes calldata performData) external {
	
	}

	function getCurrentReward() public {
		
	}

	function setPauseStatus(bool _paused) public {
			  paused = _paused;
	}

	function swapTokens(Asset from, uint amountIn) public returns(uint){

	}

	function investFunds() public {

	}

	function claimLiquidity() internal {

	}

	function chooseWinner() internal {

	}

	function getPrice(Asset asset) internal returns(uint){
		return 100056993;
	}


}

