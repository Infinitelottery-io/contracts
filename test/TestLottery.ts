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
      await expect( lottery.connect(user1).buyTickets(1, user2.address)).to.be.revertedWithCustomError(lottery, "MinimumTicketsNotReached").withArgs(10);
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
      await lottery.connect(user1).buyTickets(10000, zero);
      const participations = await lottery.allRoundsParticipatedIn(user1.address)
      expect(participations.length).to.equal(12)
      for(let i = 1; i <= 12; i++){
        expect(await lottery.ticketsL1OnRoundId(i, user1.address)).to.equal(1000);
      }
      expect(await lottery.maxRoundIdPerLevel(1)).to.equal(13);
    })
    it("should set the current round to be able to request plays")
    it("should allow a third party to buy tickets for another user")
  });
  
})