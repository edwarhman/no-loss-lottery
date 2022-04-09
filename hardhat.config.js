require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
   networks: {
      hardhat: {
         forking: {
            url: process.env.RPC_URL,
         },
      },
   },
   solidity: {
      compilers: [
         {
            version: "0.8.10",
         },
      ],
   },
};
