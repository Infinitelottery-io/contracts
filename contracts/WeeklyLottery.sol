// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWeeklyLottery.sol";
import "./interfaces/IWinnerHub.sol";
import "./interfaces/IDividendNFT.sol";
import "./interfaces/ILottery.sol";

//------------------------------------
//  ERRORS
//------------------------------------

error InfiniteLottery__InvalidNFTCount();
error InfiniteLottery__InvalidTeamWallet();

contract WeeklyLottery is IWeeklyLottery, Ownable {
    //------------------------------------------
    // Type Declarations
    //------------------------------------------

    struct RoundInfo {
        address[] buyers;
        uint[] tickets;
        uint finalPot;
        uint winnerNumber;
        address winnerAddress;
        uint vrfRequestID;
    }

    struct BuyerIndex {
        uint index;
        bool set;
    }

    //--------------------------------------
    //  MAPPINGS
    //--------------------------------------

    mapping(uint roundId => RoundInfo) public round;
    mapping(address _user => mapping(uint roundId => BuyerIndex)) public buyer;
    mapping(address _user => uint[] roundParticipation)
        public userParticipations;

    //-------------------------------------
    //  State Variables
    //--------------------------------------

    IERC20 public usdc;

    IWinnerHub public winnerHub;
    IDividendNFT public dividendNFT;
    IWeeklyLottery public weeklyDrawLottery;
    ILottery public ifl;

    uint private constant PERCENTAGE = 1000;

    uint256 public pot;

    uint[] public winDistribution = [70, 10, 10, 5, 5];

    //-----------------------------------
    //  CONSTRUCTOR
    //-----------------------------

    constructor(
        address _usdc,
        address _vrfCoordinator,
        uint64 _vrfSubId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrf = VRFCoordinatorV2Interface(_vrfCoordinator);
        // These only operate in BSC Mainnet and Testnet
        if (block.chainid == 56)
            vrfHash = 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04;
        else if (block.chainid == 97)
            vrfHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

        usdc = IERC20(_usdc);
        subid = _vrfSubId;
    }

    //TODO still pending actual implementation of rest of lottery info
    function addToPot(uint256 amount) external override {
        usdc.transferFrom(msg.sender, address(this), amount);
        pot += amount;
    }

    function buyTickets(uint amount) {}

    // Assure that NFT holders are automatically added to players list.
    // 3 NFTs need to be held to be eligible for the lottery.

    function checkNFT(address id) external override {}

    function distributeWin(address id) external override {
        uint playerWins = (pot * singleWinner) / PERCENTAGE;
        uint discount = pot - playerWins;
    }
    // Distribution
    /**
        70% for a single winner.
        10% for the next weekly pot.
        10% dividends.
        5% referral system.
        5% for the team.
     */
}
