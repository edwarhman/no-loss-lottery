const { expect } = require("chai");
const provider = waffle.provider;

describe("No Loss Lottery", () => {
   let Lottery, lottery, VRFv2Consumer, vrf2Consumer, CoordinatorMock, vrfCordinator, owner, user;
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

   const subId = 1;


   before(async () => {
      await hre.network.provider.request({
         method: "hardhat_impersonateAccount",
         params: [process.env.PUBLIC_KEY],
       });


      Lottery = await ethers.getContractFactory("LotteryTest");
      VRFv2Consumer = await ethers.getContractFactory("VRFv2Consumer");
      CoordinatorMock = await ethers.getContractFactory("CoordinatorMock");
   });

   beforeEach(async () => {
      [owner, user] = await ethers.getSigners();
      vrfCordinator = await CoordinatorMock.deploy(0, 0);
      vrf2Consumer = await VRFv2Consumer.deploy(subId, vrfCordinator.address);
      lottery = await upgrades.deployProxy(Lottery, [vrf2Consumer.address]);

      await vrf2Consumer.setLotteryContract(lottery.address);
      await vrfCordinator.createSubscription();
      await vrfCordinator.fundSubscription(subId, 100000);

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

         expect(await lottery.getTicketOwner(1)).to.equal(owner.address);

         expect(await lottery.getTicketOwner(10)).to.equal(owner.address);

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

      it("Should check round status and perform functions property", async () => {
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
            await vrfCordinator.fulfillRandomWords(1, vrf2Consumer.address);
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
      });

      it("Should allow to generate a random winning ticket", async()=> {
         let ticketsAmount = 10;

         await lottery.participate(ticketsAmount, Asset.ETH, {value: ethers.utils.parseEther("1")});
         await lottery.investFunds();
         await lottery.finishRound();
         await vrfCordinator.fulfillRandomWords(1, vrf2Consumer.address);

         expect(await lottery.winningTicket())
         .to
         .be
         .within(0, ticketsAmount);


      });
   });
});
