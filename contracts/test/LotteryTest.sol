pragma solidity ^0.8.0;
import "../Lottery.sol";

contract LotteryTest is Lottery {
   function finishRound() public {
      _finishRound();
   }
}
