pragma solidity ^0.8.0;
import "../interfaces/IRouterV2.sol";
import "hardhat/console.sol";

contract V2Router {
   address public router;

   constructor(address uniswapRouter) {
      router = uniswapRouter;
   }

   function swapEth(
      uint256 amountOut,
      address[] memory path,
      address to
   ) external payable returns (uint256[] memory) {
      return
         IRouterV2(router).swapExactETHForTokens{value: msg.value}(
            amountOut,
            path,
            to,
            block.timestamp
         );
   }

   function WETH() external view returns (address) {
      return IRouterV2(router).WETH();
   }
}
