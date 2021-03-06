pragma solidity ^0.8.0;

interface IRouterV2 {
   function WETH() external pure returns (address);

   function swapExactETHForTokens(
      uint256 amountOutMin,
      address[] calldata path,
      address to,
      uint256 deadline
   ) external payable returns (uint256[] memory amounts);

   function getAmountsOut(uint256 amountIn, address[] memory path)
      external
      view
      returns (uint256[] memory amounts);
}
