// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILottery {
    /// @notice This function buys tickets for user for the current level 1.
    /// @param _ticketAmount the amount of tickets to buy
    /// @dev extra things that this does:
    ///         - Request winner for level 1 (when it ends)
    ///         - Request winner for higher levels (when it applies)
    function buyTickets(uint _ticketAmount) external;

    /// @notice This function works the same as the previous buyTickets function except the tickets are approved to a user in particular
    /// @param _ticketAmount the amount of tickets to buy
    /// @param _user The user that will receive the tickets
    /// @dev Does the same extra steps as prev buyTickets function
    function buyTicketsForUser(uint _ticketAmount, address _user) external;

    /// @notice returns the amount of tickets needed for the next Level1 to be over;
    /// @return amount of tickets
    function ticketsToEndL1() external view returns (uint);

    /// @notice returns the amount of tickets for the next _level to be over
    /// @param _level The level to query
    /// @return amount of tickets
    function ticketsToEnd(uint _level) external view returns (uint);
}
