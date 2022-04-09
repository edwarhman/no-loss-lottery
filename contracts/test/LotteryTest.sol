pragma solidity ^0.8.0;
import "../Lottery.sol";

contract LotteryTest is Lottery {
   function finishRound() public {
      _finishRound();
   }

   function swapTokens(
      Asset from,
      Asset to,
      uint256 amountIn
   ) public returns (uint256) {
      _swapTokens(from, to, amountIn);
   }
}
