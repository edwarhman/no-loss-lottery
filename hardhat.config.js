require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
   networks: {
      hardhat: {
/*        forking: {
            url: process.env.ALCHEMY_KEY,
         }*/
      }
   },
   solidity: "0.8.12",
};
