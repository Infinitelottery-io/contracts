// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWeeklyLottery {
    /**
     * Add to current week's pot
     * @param amount USDC to add to POT
     */
    function addToPot(uint256 amount) external;
}
