// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/ILottery.sol";

contract InfiniteLottery is ILottery, VRFConsumerBaseV2 {
    struct Level1Participants {
        address[] users;
        uint[] userTickets;
    }
    struct UpperLevels {
        uint minL1;
        uint maxL1;
        bytes32 vrfRequestId;
    }
    struct WinnerInfo {
        uint[] levels;
        uint[] ids;
        uint[] winnerNumbers;
        address[] winnerAddresses;
    }
    struct UserParticipations {
        uint[] participationsL1;
        address referral;
    }
    struct UserRoundInfo {
        uint tickets;
        uint index; // Index in the users array for Level1Participants
    }
    mapping(uint _level => mapping(uint _id => UpperLevels))
        private _higherLevels;
    mapping(uint _level => mapping(uint _id => UserRoundInfo))
        public userTickets;
    mapping(uint _round => Level1Participants) private _level1;
    mapping(address _user => UserParticipations) public userPartipations;
    //TODO Make sure we have the winner info visible on request
    mapping(bytes32 randomRequest => WinnerInfo) private winnerInfo;

    IERC20 public USDC; // The only Token used here
    VRFCoordinatorV2Interface private immutable vrf;
    address public dividendNFT;
    address public discountLocker;
    address public winnerDistribution;
    address public teamWallet;

    uint public currentL1; // Advances when each L1 advances
    uint public currentHighest; // Current highest with prize pot associated with it.
    uint public currentWeeklyRound;
    uint public constant ticketsPerL1 = 1000;
    uint public constant l1Advancement = 20; // 20 rounds of L1 for a L2
    uint public constant upperAdvancement = 10; // 10 rounds of any upper level to the next level
    uint public winnerPot = 30;
    uint public rollupPot = 30;
    uint public roiPot = 20;
    uint public dividendPot = 10;
    uint public referralPot = 6;
    uint public teamPot = 2;
    uint public weeklyPot = 2;
    // VRF Stuff
    bytes32 private vrfHash;
    uint64 private subid;
    uint16 private minConfirmations = 3; // default
    uint32 private callbackGasLimit = 100000; // initial value allegedly it costs

    // numwords to request has a max of 500.

    // VRF COORDINATOR - BSC
    // 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE
    // VRF 200gwei key hash
    // 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04
    // VRF COORDINATOR - BSC TESTNET
    // 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f
    // VRF 50gwei key hash
    // 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314
    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
        vrf = VRFCoordinatorV2Interface(_vrfCoordinator);
    }
}
