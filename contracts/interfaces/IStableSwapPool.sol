pragma solidity ^0.8.0;

interface IStableSwapPool {
	///@dev get the amoun of coin j onw would receive for swapping _dx of coin i
   function get_dy(
      int128 i,
      int128 j,
      uint256 _dx
   ) external view returns (uint256);
	///@dev Perform an exchange between two coins
   function exchange(
      int128 i,
      int128 j,
      uint256 _dx,
      uint256 _min_dy
   ) external;
}
