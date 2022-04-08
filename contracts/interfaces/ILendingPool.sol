pragma solidity ^0.8.0;

interface ILendingPool {
   /**
    * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
    * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
    * @param asset The address of the underlying asset to deposit
    * @param amount The amount to be deposited
    * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
    *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
    *   is a different wallet
    * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
    *   0 if the action is executed directly by the user, without any middle-man
    **/
   function deposit(
      address asset,
      uint256 amount,
      address onBehalfOf,
      uint16 referralCode
   ) external;

   /**
    * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
    * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
    * @param asset The address of the underlying asset to withdraw
    * @param amount The underlying amount to be withdrawn
    *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
    * @param to Address that will receive the underlying, same as msg.sender if the user
    *   wants to receive it on his own wallet, or a different address if the beneficiary is a
    *   different wallet
    * @return The final amount withdrawn
    **/
   function withdraw(
      address asset,
      uint256 amount,
      address to
   ) external returns (uint256);

   /**
    * @dev Returns the user account data across all the reserves
    * @param user The address of the user
    * @return totalCollateralETH the total collateral in ETH of the user
    * @return totalDebtETH the total debt in ETH of the user
    * @return availableBorrowsETH the borrowing power left of the user
    * @return currentLiquidationThreshold the liquidation threshold of the user
    * @return ltv the loan to value of the user
    * @return healthFactor the current health factor of the user
    **/
   function getUserAccountData(address user)
      external
      view
      returns (
         uint256 totalCollateralETH,
         uint256 totalDebtETH,
         uint256 availableBorrowsETH,
         uint256 currentLiquidationThreshold,
         uint256 ltv,
         uint256 healthFactor
      );
}
