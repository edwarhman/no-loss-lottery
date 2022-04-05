const {expect} = require('chai');
const provider = waffle.provider;

describe("No Loss Lottery", ()=> {
   let Lottery, lottery, owner, user;
   let Asset = {
      DAI: 0,
      USDC: 1,
      USDT: 2,
      ETH: 3,
   };

   before(async ()=> {
      Lottery = await ethers.getContractFactory("Lottery");
   });

   beforeEach(async ()=> {
      [owner, user] = await ethers.getSigners();
      lottery = await upgrades.deployProxy(Lottery);
   });

   describe("Deployment", ()=> {
      it("Should initialize first round correctly", async ()=> {
         let round = await lottery.rounds(0);

         console.log(round);
         expect(round[3])
         .to
         .equal(Asset.USDC);
      });
   });

   describe("Participate function assertions", ()=> {

      it("Should not allow to participate when round status is complete", async()=> {
         await expect(lottery.participate(10, Asset.DAI))
         .to
         .be
         .revertedWith("Cannot participate, round status is completed");
      });
   });
   
});
