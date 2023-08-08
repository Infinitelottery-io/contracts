// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWinnerHub {
    /**
     *
     * @param _winner The address of the winner of the round
     * @param _referral The referrer of the winner
     * @param _winAmount Amount designated to the winner
     * @param _refAmount Amount designated to the referrer
     */
    function distributeWinnings(
        address _winner,
        address _referral,
        uint _winAmount,
        uint _refAmount
    ) external;

    /**
     * @notice This function allows the winner to claim their winnings in USDC
     */
    function claimWinner() external;

    /**
     * @notice Claim referral rewards
     * @dev Winner must have a referral NFT
     * @dev 10% of rewards are used to buy tickets for referrer
     */
    function claimReferral() external;

    /**
     * @notice Updates lottery in case of an upgrade
     * @param _lottery The address of the new lottery contract
     */
    function updateLottery(address _lottery) external;

    /**
     * @notice Updates NFT in case of an upgrade
     * @param _nft The address of the new NFT contract
     */
    function updateNFTAddress(address _nft) external;
}
