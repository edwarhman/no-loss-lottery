const { expect } = require("chai");
const provider = waffle.provider;

describe("No Loss Lottery", () => {
   let Lottery, lottery, VRFv2Consumer, vrf2Consumer, vrfCordinator, owner, user;
   let Asset = {
      DAI: 0,
      USDC: 1,
      USDT: 2,
      ETH: 3,
   };
   let RoundStatus = {
      collecting: 0,
      investing: 1,
      finished: 2,
   };

   let VRF_CORDINATOR = "0x6168499c0cFfCaCD319c818142124B7A15E857ab";


   before(async () => {
      await hre.network.provider.request({
         method: "hardhat_impersonateAccount",
         params: [process.env.PUBLIC_KEY],
       });


      Lottery = await ethers.getContractFactory("LotteryTest");
      VRFv2Consumer = await ethers.getContractFactory("VRFv2Consumer");
   });

   beforeEach(async () => {
      [owner, user] = await ethers.getSigners();
      lottery = await upgrades.deployProxy(Lottery);
   });

   describe("Deployment", () => {
      it("Should initialize first round correctly", async () => {
         let round = await lottery.rounds(0);

         expect(round[3]).to.equal(Asset.USDC);
      });
   });

   describe("Participate function assertions", () => {
      it("Should allow to participate in the lottery", async () => {
         await lottery.participate(10, Asset.ETH, {
            value: ethers.utils.parseEther("1"),
         });

         expect(await lottery.getTicketOwner(0)).to.equal(owner.address);

         expect(await lottery.getTicketOwner(9)).to.equal(owner.address);

         expect(await lottery.getParticipantFunds(0)).to.above(0);

         expect((await lottery.rounds(0))[1]).to.above(0);
      });

      it("Should allow the user to participate in the next lottery if current is investing funds", async () => {
         await lottery.investFunds();
         await lottery.participate(10, Asset.ETH, {
            value: ethers.utils.parseEther("1"),
         });

         expect(await lottery.getParticipantFunds(1)).to.above(0);

         expect((await lottery.rounds(1))[1]).to.above(0);
      });

      it("Should not allow to participate when round status is finished", async () => {
         await lottery.finishRound();
         await expect(lottery.participate(10, Asset.DAI)).to.be.revertedWith(
            "Cannot participate, round status is finished"
         );
      });

      it("Should not allow to participate if there is not sufficient allowance", async () => {
         await expect(lottery.participate(10, Asset.ETH)).to.be.revertedWith(
            "Token allowance is too low"
         );
      });
   });

   describe("Upkeep functions assertions", () => {
      let day = 60 * 60 * 24;
      let collectTime = day * 2;
      let investTime = day * 5;

      it("Should check round status property and perform functionst property", async () => {
         let result;

         await network.provider.send("evm_increaseTime", [collectTime]);
         await network.provider.send("evm_mine");

         result = await lottery.checkUpkeep("0x");

         if (result) {
            await lottery.performUpkeep("0x");
         }

         expect(await lottery.currentRoundStatus()).to.equal(
            RoundStatus.investing
         );

         await network.provider.send("evm_increaseTime", [
            collectTime + investTime,
         ]);
         await network.provider.send("evm_mine");

         result = await lottery.checkUpkeep("0x");

         if (result) {
            await lottery.performUpkeep("0x");
         }

         expect(await lottery.currentRoundStatus()).to.equal(
            RoundStatus.finished
         );

         result = await lottery.checkUpkeep("0x");

         if (result) {
            await lottery.performUpkeep("0x");
         }

         expect(await lottery.currentRoundStatus()).to.equal(
            RoundStatus.collecting
         );
      });
   });

   describe("Generate winning number", ()=> {
      beforeEach(async()=> {
         user = await ethers.getSigners(process.env.PUBLIC_KEY);
         vrf2Consumer = await VRFv2Consumer.deploy(process.env.VRF_ID);
         vrfCordinator = await ethers.getContractAt("IVRF",VRF_CORDINATOR);
      });

      it("Should allow to generate a random number", async()=> {
         console.log(vrf2Consumer.address);
         await vrfCordinator.addConsumer(0, vrf2Consumer.address);
         console.log(await vrfCordinator.getSubscription(0));
         
      });
   });
});
