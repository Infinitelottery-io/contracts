// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWeeklyLottery {
    /**
     * Add to current week's pot
     * @param amount USDC to add to POT
     */
    function addToPot(uint256 amount) external;

    /**
     * Buy Tickets for user
     * @param amount Amount of tickets to buy
     * @dev User must have approved USDC to be spent by this contract
     * @dev User must have bought lottery tickets in the current week
     * @dev On new round, dividend NFTs get X amount of tickets for free
     *  // Assure that NFT holders are automatically added to players list.
        // 3 NFTs need to be held to be eligible for the lottery.
     */
    function buyTickets(uint256 amount) external;

    function buyTicketsForUser(uint amount, address user) external;

    function checkUpkeep(
        bytes calldata
    ) external returns (bool upkeepNeeded, bytes memory performData);

    /**
     *
     * @param performData Not sure if used yet
     * @dev This function can only be called after lottery round ends
     * @dev This function requests a random number from Chainlink VRF to determine the winner
     *    - fulfillRandomness() is called by Chainlink VRF
     *    - 1) truncate number to amount of tickets bought in this round.
     */
    function performUpkeep(bytes calldata performData) external;

    /**
     * Register nft holder to participate in weekly lottery
     * @param ids NFT ids to register
     * @dev Ids are not duplicated
     */
    function registerNFTHolder(uint[] calldata ids) external;

    function nftsHeld(address user) external view returns (uint);

    /**
     * Winner earnings are sent to the WINNER HUB contract for distribution
     * Distribution
        70% for a single winner.
        10% for the next weekly pot.
        10% dividends.
        5% referral system.
        5% for the team.
     */
}
