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
}
