# Infinite Lottery Contracts

## How does it work

There are 3 core contracts that make up the Infinite Lottery ecosystem.

1. InfiniteLottery - Main lottery logic and weekly lottery logic
2. WinnerHub - Only winner claim logic
3. DiscountBooth - Only discount buy logic

A brief diagram of this is:

![Infinite Lottery diagram](./imgs/contract%20diagram.png?raw=true)

### Why is it spread into 3 different contracts instead of a single monolithic one?

Short answer, it's easier to keep track of different values and makes it simpler for community users to keep tabs on where the money is. Also testing becomes less tedious since the logic is fairly spread out.

## Technical Specifications

### Overview

The code is all written in solidity and uses the already battle tested libraries from OpenZeppelin as well as the VRF from Chainlink.

#### Limitations

Due to the reliance on Chainlink to receive random numbers, that means we're restricted to proper operation on Chainlink supported networks.

##### Workaround & Disclaimer

The only workaround at the moment is for us to deploy our own random number logic, which would work, but it would not be decentralized enough for anyone to make sure that the winning users were not handpicked. Mainly because the logic in the contract is discreet and with a particular number we can select specific winners.
