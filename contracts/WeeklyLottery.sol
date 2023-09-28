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
error IFLWeekly__InvalidNFTid();

contract WeeklyLottery is IWeeklyLottery, Ownable {
    //------------------------------------------
    // Type Declarations
    //------------------------------------------

    struct RoundInfo {
        address[] buyers;
        uint[] tickets;
        address[] bonusHolders;
        uint[] bonusTickets;
        address winnerAddress;
        uint finalPot;
        uint winnerNumber;
        uint vrfRequestID;
        uint ticketsBought;
        uint nftTickets;
    }

    struct BuyerIndex {
        uint index;
        bool set;
    }

    struct NFTRegistration {
        uint[] ids;
        uint rewardTickets;
        uint indexOfDividendInfo;
        bool dividendInfoSet;
    }
    struct NFTIdRegistrar {
        address user;
        uint userNFTRegistrationIndex;
    }

    //--------------------------------------
    //  MAPPINGS
    //--------------------------------------

    mapping(uint roundId => RoundInfo) public round;
    mapping(address _user => mapping(uint roundId => BuyerIndex)) public buyer;
    mapping(address _user => uint[] roundParticipation)
        public userParticipations;
    mapping(uint nftId => NFTIdRegistrar) public nftIdRegistrar;
    mapping(address dividendOwner => NFTRegistration)
        public dividendOwnerRegistrationInfo;

    //-------------------------------------
    //  State Variables
    //--------------------------------------
    address[] public bonusTicketHolders;
    uint[] public bonusTicketsPerHolder;
    uint[] public winDistribution = [70, 10, 10, 5, 5];

    IERC20 public usdc;

    IWinnerHub public winnerHub;
    IDividendNFT public dividendNFT;
    IWeeklyLottery public weeklyDrawLottery;
    ILottery public ifl;

    uint private constant PERCENTAGE = 1000;

    uint256 public pot;

    uint private MIN_NFT_REGISTRATION = 2;

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

    function registerNFTHolder(uint[] calldata idsToRegister) external {
        uint length = idsToRegister.length;
        NFTRegistration storage currentUser = dividendOwnerRegistrationInfo[
            msg.sender
        ];
        // Checking Loop
        for (uint i = 0; i < length; i++) {
            uint currentId = idsToRegister[i];
            if (dividendNFT.ownerOf(currentId) != msg.sender)
                revert IFLWeekly__InvalidNFTid();

            NFTIdRegistrar storage currentRegistrar = nftIdRegistrar[currentId];
            if (currentRegistrar.user == msg.sender) continue;
            if (currentRegistrar.user != address(0)) {
                // deregister from prev user
                // TODO create private function that handles deregistration
                NFTRegistration
                    storage prevOwner = dividendOwnerRegistrationInfo[
                        currentRegistrar.user
                    ];
                uint lastIndex = prevOwner.ids.length - 1;
                uint lastId = prevOwner.ids[lastIndex];
                prevOwner.ids[
                    currentRegistrar.userNFTRegistrationIndex
                ] = lastId;
                nftIdRegistrar[lastId] = currentRegistrar
                    .userNFTRegistrationIndex;
                prevOwner.ids.pop();
                _checkDividendTicketValidity(currentRegistrar.user);
                // todo CHECK IF USER IS STILL VALID IN DIVIDEND TICKETS
            }
            currentRegistrar.user = msg.sender;
            currentRegistrar.userNFTRegistrationIndex = currentUser.ids.length;
            currentUser.ids.push(currentId);
            _checkDividendTicketValidity(msg.sender);
        }
    }

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

    function _checkDividendTicketValidity(address user) private {
        NFTRegistration storage currentUser = dividendOwnerRegistrationInfo[
            user
        ];
        if (currentUser.ids.length > MIN_NFT_REGISTRATION) {
            if (!currentUser.dividendInfoSet) {
                currentUser.dividendInfoSet = true;
                currentUser.indexOfDividendInfo = bonusTicketHolders.length;
                bonusTicketHolders.push(user);
            }
            // TODO change tickets rewarded
        } else if (currentUser.dividendInfoSet) {
            currentUser.dividendInfoSet = false;
            uint lastIndex = bonusTicketHolders.length - 1;
            address lastIndexUser = bonusTicketHolders[lastIndex];

            bonusTicketHolders[currentUser.indexOfDividendInfo] = lastIndexUser;
            dividendOwnerRegistrationInfo[lastIndexUser]
                .indexOfDividendInfo = currentUser.indexOfDividendInfo;

            bonusTicketHolders.pop();
        }
    }
}
