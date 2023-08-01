// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWeeklyLottery.sol";

contract WeeklyLottery is IWeeklyLottery {
    uint256 public pot;
    IERC20 public usdc;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    //TODO still pending actual implementation of rest of lottery info
    function addToPot(uint256 amount) external override {
        usdc.transferFrom(msg.sender, address(this), amount);
        pot += amount;
    }
    // Assure that NFT holders are automatically added to players list.
    // 3 NFTs need to be held to be eligible for the lottery.

    // Distribution
    /**
        70% for a single winner.
        10% for the next weekly pot.
        10% dividends.
        5% referral system.
        5% for the team.
        5% referral system.
     */
}
