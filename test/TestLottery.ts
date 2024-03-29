import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { parseEther } from 'ethers/lib/utils';
import { expect } from "chai";
import { ethers } from 'hardhat'

const zero = ethers.constants.AddressZero;

describe("Lottery", function (){
  const setup = async () => {
    const [owner, user1, user2, user3, placeholder] = await ethers.getSigners();
    const MockUSDC = await ethers.getContractFactory("TestToken", owner);
    const usdc = await MockUSDC.deploy();
    const Lottery = await ethers.getContractFactory("InfiniteLottery", owner);
    const lottery = await Lottery.deploy(placeholder.address, usdc.address, parseEther("1"));
    //  Transfer USDC to users
    await usdc.transfer(user1.address, parseEther("10001"));
    await usdc.transfer(user2.address, parseEther("10001"));
    await usdc.transfer(user3.address, parseEther("10001"));
    return { owner, user1, user2, user3, placeholder, usdc, lottery };
  }
  describe("Intial state", function () {
    it("should not allow to buy tickets", async () => {
      const { lottery, user1, user2 } = await loadFixture(setup);
      await expect(lottery.connect(user1).buyTickets(1, user2.address)).to.be.revertedWith("Not started");
    })
    it("should set the appropriate price", async () => {
      const { lottery } = await loadFixture(setup);
      expect(await lottery.ticketPrice()).to.equal(parseEther("1"));
    })
    it("should start with rounds at zero", async () => {
      const { lottery } = await loadFixture(setup);
      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(0);
      expect(await lottery.maxRoundIdPerLevel(2)).to.equal(0);
      expect(await lottery.maxRoundIdPerLevel(3)).to.equal(0);
    })
  });
  const lotteryStart = async () => {
    const init = await setup();
    await init.lottery.connect(init.owner).startLottery();
    return init;
  }
  describe("On ticket buys", () => {
    it("should allow to buy tickets and set roi tickets", async () => {
      const { lottery, usdc, user1, user2 } = await loadFixture(lotteryStart);
      
      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(1);
      await expect( lottery.connect(user1).buyTickets(1, user2.address)).to.be.revertedWithCustomError(lottery, "InfiniteLottery__MinimumTicketsNotReached").withArgs(10);
      await expect( lottery.connect(user1).buyTickets(10, user2.address)).to.be.revertedWith("ERC20: insufficient allowance");

      await usdc.connect(user1).approve(lottery.address, parseEther("10000"));

      await lottery.connect(user1).buyTickets(10, zero);

      expect(await lottery.userParticipations(user1.address)).to.equal(zero);
      const participations = await lottery.allRoundsParticipatedIn(user1.address)
      const round1L1U1 = await lottery.ticketsL1OnRoundId(1, user1.address)
      const round2L1U1 = await lottery.ticketsL1OnRoundId(2, user1.address)
      expect(round1L1U1).to.equal(10);
      expect(participations[0]).to.equal(1);
      expect(participations[1]).to.equal(2);
      expect(participations.length).to.equal(2);
      expect(round2L1U1).to.equal(2);
    });
    it("should set the appropriate tickets when going above max tickets for the round and overflowing", async () => {
      const { lottery, usdc, user1, user2 } = await loadFixture(lotteryStart);
      await usdc.connect(user1).approve(lottery.address, parseEther("10000"));
      await usdc.connect(user2).approve(lottery.address, parseEther("10000"));
      await lottery.connect(user1).buyTickets(10000, zero);
      const participations = await lottery.allRoundsParticipatedIn(user1.address)
      expect(participations.length).to.equal(16)
      for(let i = 1; i <= 12; i++){
        expect(await lottery.ticketsL1OnRoundId(i, user1.address)).to.equal(1000);
      }
      expect(await lottery.ticketsL1OnRoundId(13, user1.address)).to.equal(400);
      expect(await lottery.ticketsL1OnRoundId(14, user1.address)).to.equal(80);
      expect(await lottery.ticketsL1OnRoundId(15, user1.address)).to.equal(16);
      expect(await lottery.ticketsL1OnRoundId(16, user1.address)).to.equal(3);
      expect(await lottery.getRoiLeftOver(15)).to.equal(parseEther("0.2"))


      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(13);
      await lottery.connect(user2).buyTickets(1000, zero);
      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(14);
      expect(await lottery.ticketsL1OnRoundId(13, user2.address)).to.equal(600);
      expect((await lottery.getLevel1Info(14)).totalTickets).to.equal(480);
      expect((await lottery.getLevel1Info(15)).totalTickets).to.equal(216);
      expect((await lottery.getLevel1Info(16)).totalTickets).to.equal(43);
      expect((await lottery.getLevel1Info(17)).totalTickets).to.equal(8);
      expect((await lottery.getLevel1Info(18)).totalTickets).to.equal(1);
    })
    it("Should set roi overflow amounts on each round appropriately", async () => {
      const { lottery, usdc, user1, user2 } = await loadFixture(lotteryStart);
      await usdc.connect(user1).approve(lottery.address, parseEther("10000"));
      await lottery.connect(user1).buyTickets(66, zero);

      expect(await lottery.getRoiLeftOver(1)).to.equal(parseEther("0.2"))
      expect(await lottery.getRoiLeftOver(2)).to.equal(parseEther("0.6"))
      expect(await lottery.getRoiLeftOver(3)).to.equal(parseEther("0"))
      // expect(await lottery.)

    })
    it("should set the current round to be able to request plays", async () => {
      const { lottery, usdc, user1, user2 } = await loadFixture(lotteryStart);
      await usdc.connect(user1).approve(lottery.address, parseEther("10000"));
      await usdc.connect(user2).approve(lottery.address, parseEther("10000"));
      await lottery.connect(user1).buyTickets(1000, zero);
      await lottery.connect(user2).buyTickets(1000, zero);
      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(3);

      // Check that tickets are assigned correctly on multiple buys of same round
      expect(await lottery.ticketsL1OnRoundId(1, user1.address)).to.equal(1000);
      expect(await lottery.ticketsL1OnRoundId(2, user1.address)).to.equal(200);
      expect(await lottery.ticketsL1OnRoundId(2, user2.address)).to.equal(800);
      expect(await lottery.ticketsL1OnRoundId(3, user2.address)).to.equal(200);
      expect(await lottery.ticketsL1OnRoundId(4, user2.address)).to.equal(200);

      expect(await lottery.totalRoundsToPlay()).to.equal(2);
      expect(await lottery.roundsToPlay(0)).to.equal(1);
      expect(await lottery.roundsToPlay(1)).to.equal(2);

    })
  });
})