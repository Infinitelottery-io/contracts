// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IWinnerHub {

  /**
   * 
   * @param _winner The address of the winner of the round
   * @param _referral The referrer of the winner
   * @param _winAmount Amount designated to the winner
   * @param _refAmount Amount designated to the referrer
   */
  function distributeWinnings(address _winner, address _referral, uint _winAmount, uint _refAmount) external;

}