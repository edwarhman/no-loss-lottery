const {expect} = require("chai");
const provider = waffle.provider;

describe("No Loss Lottery", () => {
   let Lottery,
      lottery,
      VRFv2Consumer,
      vrf2Consumer,
      CoordinatorMock,
      vrfCordinator,
      tokenContract,
      RouterV2,
      routerV2,
		swapPool3,
      owner,
      user;
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

	const anEther = ethers.utils.parseEther("1");

   const subId = 1;

   const tokenAddresses = [
      "0x6B175474E89094C44Da98b954EedeAC495271d0F",
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
   ];

	const tokenDecimals = [
		18,
		6,
		6,
		18
	];
   const poolAddress = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";
   const uniswapRouterAddress =
      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
	const swapPool3Address = "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7";

   before(async () => {
      Lottery = await ethers.getContractFactory("LotteryTest");
      VRFv2Consumer = await ethers.getContractFactory(
         "VRFv2Consumer"
      );
      CoordinatorMock = await ethers.getContractFactory(
         "CoordinatorMock"
      );
      RouterV2 = await ethers.getContractFactory("V2Router");
   });

   beforeEach(async () => {
      [owner, user] = await ethers.getSigners();
      vrfCordinator = await CoordinatorMock.deploy(0, 0);
      vrf2Consumer = await VRFv2Consumer.deploy(
         subId,
         vrfCordinator.address
      );
      lottery = await upgrades.deployProxy(Lottery, [
         vrf2Consumer.address,
         tokenAddresses,
			tokenDecimals,
         poolAddress,
      ]);
      tokenContract = await ethers.getContractAt(
         "IERC20",
         tokenAddresses[Asset.USDC]
      );
		swapPool3 = await ethers.getContractAt(
			"IStableSwapPool",
			swapPool3Address
		);
      routerV2 = await RouterV2.deploy(uniswapRouterAddress);

      await vrf2Consumer.setLotteryContract(lottery.address);
      await vrfCordinator.createSubscription();
      await vrfCordinator.fundSubscription(subId, 100000);
      await routerV2.swapEth(
         0,
         [tokenAddresses[Asset.ETH], tokenAddresses[Asset.USDC]],
         owner.address,
         {value: ethers.utils.parseEther("20")}
      );
      await tokenContract.transfer(
         lottery.address,
         await tokenContract.balanceOf(owner.address)
      );
   });

	describe("Swap pool3", ()=> {
		it("Should swap tokens", async()=> {
			await routerV2.swapEth(
				0,
				[tokenAddresses[Asset.ETH], tokenAddresses[Asset.USDC]],
				owner.address,
				{value: ethers.utils.parseEther("20")}
			);
			let daiCoin = await ethers.getContractAt("IERC20", tokenAddresses[Asset.DAI]);
			
			let expected = await swapPool3.get_dy(1, 0, 10000000);
			console.log(expected);
			console.log(await swapPool3.get_dy(0, 1, anEther));
			await tokenContract.approve(swapPool3Address, 10000000);
			await swapPool3.exchange(1, 0, 10000000, expected.mul(99).div(100));
			console.log(expected.mul(99).div(100));
			let result = await daiCoin.balanceOf(owner.address);
			expect(result).to.be.within(1, expected);

		});
	});

	xdescribe("Deployment", () => {
		it("Should initialize first round correctly", async () => {
			let round = await lottery.rounds(0);

			expect(round[3]).to.equal(Asset.USDC);
			expect(await lottery.tokenAddress(Asset.ETH)).to.equal(
				tokenAddresses[Asset.ETH]
			);
			expect(await lottery.assetPoolAddress()).to.equal(
				poolAddress
			);
		});
	});

	xdescribe("Participate function assertions", () => {
		it("Should allow to participate in the lottery", async () => {
			await lottery.participate(10, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});

			expect(await lottery.getTicketOwner(1)).to.equal(
				owner.address
			);

			expect(await lottery.getTicketOwner(10)).to.equal(
				owner.address
			);

			expect(await lottery.getParticipantFunds(0)).to.above(0);

			expect((await lottery.rounds(0))[1]).to.above(0);
		});

		it("Should allow the user to participate in the next lottery if current is investing funds", async () => {
			await lottery.participate(3, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});
			await lottery.investFunds();
			await lottery.participate(10, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});

			expect(await lottery.getParticipantFunds(1)).to.above(0);

			expect((await lottery.rounds(1))[1]).to.above(0);
		});

		it("Should not allow to participate when round status is finished", async () => {
			await lottery.participate(3, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});
			await lottery.investFunds();
			await lottery.finishRound();
			await expect(
				lottery.participate(10, Asset.DAI)
			).to.be.revertedWith(
				"Cannot participate, round status is finished"
			);
		});

		it("Should not allow to participate if there is not sufficient allowance", async () => {
			await expect(
				lottery.participate(10, Asset.ETH)
			).to.be.revertedWith("Token allowance is too low");
		});
	});

	xdescribe("Upkeep functions assertions", () => {
		let day = 60 * 60 * 24;
		let collectTime = day * 2;
		let investTime = day * 5;

		it("Should check round status and perform functions property", async () => {
			let result;

			await lottery.participate(3, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});

			await network.provider.send("evm_increaseTime", [
				collectTime,
			]);
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
				await vrfCordinator.fulfillRandomWords(
					1,
					vrf2Consumer.address
				);
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

	xdescribe("Generate winning number", () => {
		beforeEach(async () => {
			user = await ethers.getSigners(process.env.PUBLIC_KEY);
		});

		it("Should allow to generate a random winning ticket", async () => {
			let ticketsAmount = 10;

			await lottery.participate(ticketsAmount, Asset.ETH, {
				value: ethers.utils.parseEther("1"),
			});
			await lottery.investFunds();
			await lottery.finishRound();
			await vrfCordinator.fulfillRandomWords(
				1,
				vrf2Consumer.address
			);

			expect(await lottery.winningTicket()).to.be.within(
				0,
				ticketsAmount
			);
		});
	});
});
