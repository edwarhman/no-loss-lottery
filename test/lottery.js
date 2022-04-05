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

         expect(round[3])
         .to
         .equal(Asset.USDC);
      });
   });

   describe("Participate function assertions", ()=> {

      it("Should allow to participate in the lottery", async()=> {
         await lottery.participate(10, Asset.ETH, {value: ethers.utils.parseEther("1")});

         expect(await lottery.getTicketOwner(0))
         .to
         .equal(owner.address);

         expect(await lottery.getTicketOwner(9))
         .to
         .equal(owner.address);

         expect(await lottery.participantsFundsByRound(owner.address, 0))
         .to
         .above(0);

         expect((await lottery.rounds(0))[1])
         .to
         .above(0);
      });

      it("Should allow the user to participate in the next lottery if current is investing funds", async()=> {
         await lottery.investFunds();

         console.log(await lottery.rounds(0));
         await lottery.participate(10, Asset.ETH, {value: ethers.utils.parseEther("1")});

         expect(await lottery.getTicketOwner(0))
         .to
         .equal(owner.address);

         expect(await lottery.getTicketOwner(9))
         .to
         .equal(owner.address);

         console.log(await lottery.rounds(0));
         console.log(await lottery.participantsFundsByRound(owner.address, 0));


         expect(await lottery.participantsFundsByRound(owner.address, 1))
         .to
         .above(0);

         expect((await lottery.rounds(1))[1])
         .to
         .above(0);


      });

      it("Should not allow to participate when round status is complete", async()=> {
         await expect(lottery.participate(10, Asset.DAI))
         .to
         .be
         .revertedWith("Cannot participate, round status is completed");
      });
   });
   
});
