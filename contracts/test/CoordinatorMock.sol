pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract CoordinatorMock is VRFCoordinatorV2Mock {
   constructor(uint96 _baseFee, uint96 _gasPriceLink)
      VRFCoordinatorV2Mock(_baseFee, _gasPriceLink)
   {}
}
