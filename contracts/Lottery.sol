// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/IWinnerHub.sol";
// TODO REMOVE TEST LIBRARY
import "hardhat/console.sol";

error InfiniteLottery__NoRoundsToPlay();
error InfiniteLottery__MinimumTicketsNotReached(uint minTickets);
error InfiniteLottery__HighValue(uint valueSent);
error InfiniteLottery__InvalidWinnerHub();

contract InfiniteLottery is ILottery, VRFConsumerBaseV2, Ownable, ReentrancyGuard {
    //-------------------------------------------------------------------------
    //    Type Declarations
    //-------------------------------------------------------------------------
    struct Level1Participants {
        uint[] ticketsPerUser;
        uint totalTickets;
        uint roiOverflow;
        uint bulkId; // We'll only be using a single request ID for multiple levels, the winner will be using shifted values from the randomness
        uint winnerIndex;
        address[] users;
    }
    struct UpperLevels {
        uint minL1;
        uint maxL1;
        uint currentPot;
        uint bulkId; // We'll only be using a single request ID for multiple levels, the winner will be using shifted values from the randomness
        uint winnerIndex;
    }
    struct WinnerInfo {
        uint level;
        uint id;
        uint winnerNumber;
        address winnerAddress;
    }
    struct UserParticipations {
        uint[] participationsL1;
        address referral;
    }
    struct UserRoundInfo {
        uint tickets;
        uint index; // Index in the users array for Level1Participants
        bool set;
    }
    //-------------------------------------------------------------------------
    //    State Variables
    //-------------------------------------------------------------------------
    mapping(uint _level => mapping(uint _id => UpperLevels)) private _higherLevels;
    mapping(uint _round => Level1Participants) private _level1;
    mapping(address _user => UserParticipations) public userParticipations;
    mapping(address _user => mapping(uint _level1Id => UserRoundInfo)) public userTickets;
    //TODO Make sure we have the winner info visible on request
    mapping(uint bulkId => uint vrfRequestID) private bulkIdToVrfRequestID;
    mapping(uint vrfRequestId => uint bulkId) private vrfRequestToBulkId;
    mapping(uint bulkId => WinnerInfo[]) private winnerInfo;
    mapping(uint _level => uint maxId) public maxRoundIdPerLevel;

    uint[] public roundsToPlay; // Only level_1 IDs here.

    IERC20 public USDC; // The only Token used here
    // BSC USDC address = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
    VRFCoordinatorV2Interface private immutable vrf;
    IWinnerHub public winnerHub;
    address public dividendNFT;
    address public discountLocker;
    address public winnerDistribution;
    address public teamWallet;

    uint private bulkId = 0; // current id of the bulk of winner info to get
    uint public currentHighest; // Current highest with prize pot associated with it.
    uint public currentWeeklyRound;
    uint public constant ticketsPerL1 = 1000;
    uint public constant l1Advancement = 20; // 20 rounds of L1 for a L2
    uint public constant upperAdvancement = 10; // 10 rounds of any upper level to the next level
    uint public immutable ticketPrice;
    uint public winnerPot = 30;
    uint public rollupPot = 30;
    uint public roiPot = 20;
    uint public dividendPot = 10;
    uint public referralPot = 6;
    uint public teamPot = 2;
    uint public weeklyPot = 2;
    uint public constant BASE_DISTRIBUTION = 100;
    uint public MINIMUM_TICKETS_PER_BUY = 10;

    // VRF Stuff
    bytes32 private vrfHash;
    uint64 private subid;
    uint16 private minConfirmations = 3; // default
    uint32 private callbackGasLimit = 100000; // initial value allegedly it costs

    //-------------------------------------------------------------------------
    //    EVENTS
    //-------------------------------------------------------------------------
    event LotteryStarted(uint timestamp);
    event TicketsBought(
        address indexed user,
        uint _level1RoundId,
        uint ticketAmount
    );
    event SetNewMinimumTicketBuy(uint prev, uint _new);
    event AdvanceRound(uint level, uint newRoundId);

    // numwords to request has a max of 500.

    // VRF COORDINATOR - BSC
    // 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE
    // VRF 200gwei key hash
    // 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04
    // VRF COORDINATOR - BSC TESTNET
    // 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f
    // VRF 50gwei key hash
    // 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314
    //-------------------------------------------------------------------------
    //    Constructor
    //-------------------------------------------------------------------------
    constructor(
        address _vrfCoordinator,
        address _usdc,
        uint _ticketPrice
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrf = VRFCoordinatorV2Interface(_vrfCoordinator);
        USDC = IERC20(_usdc);
        ticketPrice = _ticketPrice;
    }
    //-------------------------------------------------------------------------
    //    External Functions
    //-------------------------------------------------------------------------
    function startLottery() external onlyOwner {
        require(maxRoundIdPerLevel[1] == 0, "Already started");
        maxRoundIdPerLevel[1] = 1;
        _higherLevels[2][1] = UpperLevels(1, 0, 0, 0, 0);
        emit LotteryStarted(block.timestamp);
    }

    function buyTickets(uint _ticketAmount, address _referral) external {
        _buyTickets(_ticketAmount, _referral, msg.sender);
    }

    function buyTicketsForUser(
        uint _ticketAmount,
        address _referral,
        address _user
    ) external {
        _buyTickets(_ticketAmount, _referral, _user);
    }

    // This will be called by the contract itself to advance rounds internally
    // honestly this is mainly for testing purposes. But it's a good way to do it in case someone decides to
    // buy a lot of tickets from the get go.
    function playRounds() public nonReentrant{
        // make sure that there are rounds to play
        if(roundsToPlay.length == 0) 
            revert InfiniteLottery__NoRoundsToPlay();

        
        uint requestNumbers;
        uint round1Pot = ticketsPerL1 * ticketPrice;

        WinnerInfo[] storage winnerChoose = winnerInfo[bulkId];
        // Start to loop through available rounds to play
        for( uint i = 0; i < roundsToPlay.length; i++){
            // We need to transfer out the roiOverflow
            // Distribute POT to next round and other users (?) OR do we do this after we have the winner tickets picked?
            Level1Participants storage level1 = _level1[roundsToPlay[i]];
            WinnerInfo memory winnerLog = WinnerInfo({
                level: 1,
                id: roundsToPlay[i],
                winnerAddress: address(0),
                winnerNumber: 0
            });
            // Record where the info for the winner is stored
            level1.bulkId = bulkId;
            level1.winnerIndex = winnerChoose.length;
            if(level1.users.length == 1){
                winnerLog.winnerAddress = level1.users[0];
                distributeWins(winnerLog.winnerAddress, 1);
            }
            else
                requestNumbers ++;
            winnerChoose.push(winnerLog);

            // set POT info on higherlevel
            _higherLevels[2][maxRoundIdPerLevel[2]].currentPot += rollupPot * round1Pot / BASE_DISTRIBUTION;
            
        }
        // split rounds to play in fragments of 5 rounds (?), we should definitely have this shit tested.
        // after this is called, then we can safely reset the array of rounds to play.

        // Increase BulkId count
        bulkId ++;
        // reset the results array;
        roundsToPlay = new uint[](0);
    }

    function setMinimumTicketBuy(uint _newAmount) external onlyOwner {
        if (_newAmount > 100) revert InfiniteLottery__HighValue(_newAmount);
        emit SetNewMinimumTicketBuy(MINIMUM_TICKETS_PER_BUY, _newAmount);
        MINIMUM_TICKETS_PER_BUY = _newAmount;
    }

    function setWinnerHub(address _hub) external onlyOwner {
        if(_hub == address(0))
            revert InfiniteLottery__InvalidWinnerHub();
        winnerHub = IWinnerHub(_hub);
        USDC.approve(_hub, type(uint).max); // max approval
    }

    function increaseHubApproval()external {
        USDC.approve(address(winnerHub), type(uint).max); // max approval
    }

    //-------------------------------------------------------------------------
    //    Internal Functions
    //-------------------------------------------------------------------------

    function fulfillRandomWords(
        uint requestId,
        uint256[] memory randomWords
    ) internal override {
        console.log("Fulfill request", requestId, randomWords.length);
    }
    //-------------------------------------------------------------------------
    //    Private Functions
    //-------------------------------------------------------------------------

    function _buyTickets(
        uint _ticketAmount,
        address _referral,
        address _user
    ) private nonReentrant{
        require(maxRoundIdPerLevel[1] > 0, "Not started");
        if (_ticketAmount < 10) revert InfiniteLottery__MinimumTicketsNotReached(10);
        UserParticipations storage userPlays = userParticipations[_user];
        uint leftovers;
        uint roiTickets;
        uint level1Played = maxRoundIdPerLevel[1];
        UserRoundInfo storage userPlaying = userTickets[_user][level1Played];
        // set referral
        if (
            userPlays.referral == address(0) &&
            userPlays.referral != _user &&
            _referral != address(0)
        ) userPlays.referral = _referral;
        // SET TICKETS THAT ARE BOUGHT
        // TODO need to send roiLeftOver to a global value for Team wallet
        (leftovers, level1Played, roiTickets) = _createTickets(
            _ticketAmount,
            level1Played,
            true,
            _user,
            userPlaying
        );
        // OVERFLOW OF CURRENT ROUND
        if (leftovers > 0) {
            do {
                userPlaying = userTickets[_user][level1Played];
                (leftovers, level1Played, ) = _createTickets(
                    leftovers,
                    level1Played,
                    false,
                    _user,
                    userPlaying
                );
            } while (leftovers > 0);
        }
        // NOW SET THE ROI TICKETS FOR THE NEXT ROUND
        userPlaying = userTickets[_user][level1Played];
        (leftovers, level1Played, ) = _createTickets(
            roiTickets,
            level1Played,
            false,
            _user,
            userPlaying
        );
        // IF NEXT ROUND OVERFLOW... this scenario might not be needed
        // but who really knows how crazy rich people think. Better safe than sorry
        if (leftovers > 0) {
            do {
                userPlaying = userTickets[_user][level1Played];
                (leftovers, level1Played, ) = _createTickets(
                    leftovers,
                    level1Played,
                    false,
                    _user,
                    userPlaying
                );
            } while (leftovers > 0);
        }

        // Transfer money in
        uint potAddition = _ticketAmount * ticketPrice;
        USDC.transferFrom(msg.sender, address(this), potAddition);
        // check roiPot amount, if it's not a multiple of 1 ether
        // the remainder needs to be sent to  team wallet.
    }

    /** @notice Creates in a level for the user
    *   @param amount ticket amount to create, can go above max l1 tickets
    *   @param levelId the l1 id where tickets are added
    *   @param generatesROI this should only be true once on buys, rest of time should be false
    *   @return leftoverTickets the amount of tickets that overflow current round
    *   @return nextId the next level 1 round
    *   @return roiTickets the amount of tickets to claim for the next round
    *   @dev roiLeftOver  the amount (in cents) of what should go to the discount pool
    **/ 
    function _createTickets(
        uint amount,
        uint levelId,
        bool generatesROI,
        address _user,
        UserRoundInfo storage userPlaying
    ) private returns (uint leftoverTickets, uint nextId, uint roiTickets) {
        uint roiLeftOver;
        Level1Participants storage playLevel = _level1[levelId];
        // Get the ROI values from here when necessary
        if (generatesROI) {
            roiTickets = (amount * roiPot) / 100;
            roiLeftOver = (amount * ticketPrice * roiPot) / 100;
            roiLeftOver = roiLeftOver % ticketPrice;
        }
        nextId = levelId + 1;
        if (!userPlaying.set) {
            userPlaying.index = playLevel.users.length;
            userPlaying.set = true;
            playLevel.users.push(_user);
            playLevel.ticketsPerUser.push(0);
            userParticipations[_user].participationsL1.push(levelId);
        }
        // get actual amount of tickets to use this time
        leftoverTickets = playLevel.totalTickets + amount;
        if (leftoverTickets >= ticketsPerL1) {
            leftoverTickets = leftoverTickets - ticketsPerL1;
            amount = ticketsPerL1 - playLevel.totalTickets;
            userPlaying.tickets += amount;
            playLevel.totalTickets = ticketsPerL1;
            roundsToPlay.push(levelId);
            maxRoundIdPerLevel[1]++;
        } else {
            userPlaying.tickets += amount;
            playLevel.totalTickets = leftoverTickets; //overwrite value
            leftoverTickets = 0;
        }
        playLevel.ticketsPerUser[userPlaying.index] = userPlaying.tickets;
        if (roiLeftOver > 0) playLevel.roiOverflow += roiLeftOver;
        emit TicketsBought(_user, levelId, amount);
    }

    function distributeWins(address _winner, uint level) private {
        address ref = userParticipations[_winner].referral;
        uint amount = ticketsPerL1 * ticketPrice;
        uint refAmount = 0;
        if(level == 2)
            amount *= 20;
        if(level > 2)
            amount *= 10 ** (level - 2);
        if (ref != address(0)) {
            refAmount = amount * referralPot / BASE_DISTRIBUTION;
        }
        amount = amount * winnerPot / BASE_DISTRIBUTION;
        winnerHub.distributeWinnings(_winner, ref, amount, refAmount);
    }

    // lets set this data when requesting random round info
    // function queueHigherLevelToPlay(uint currentLevel, uint currentId) private {
    //     bool advances;
    //     uint requirement = currentLevel == 1 ? l1Advancement : upperAdvancement;
    //     advances = currentId % requirement == 0;

    //     if (advances) {
    //         // set the maxL1 for the previous upper level ID
    //         uint nextLevel = currentLevel + 1;
    //         uint nextId = maxRoundIdPerLevel[nextLevel];
    //         // set the max of current nextLevel
    //         _higherLevels[nextLevel][nextId].maxL1 = currentId;
    //         // get the next max Id to set the minimum
    //         nextId ++;
    //         // Set the minimum of the next level Round
    //         if(currentLevel == 1) // if next Level is 2
    //           _higherLevels[nextLevel][nextId].minL1 = currentId + 1;
    //         else{
    //           _higherLevels[nextLevel][nextId].minL1 = _higherLevels[currentLevel][currentId + 1].minL1;
    //         }
    //         // increase current ID
    //         nextId = currentId + 1;
    //         maxRoundIdPerLevel[currentLevel] = nextId;
    //         emit AdvanceRound(currentId, nextId);
    //         queueHigherLevelToPlay(nextLevel, nextId);
    //     }
    // }

    //-------------------------------------------------------------------------
    //    External & Public VIEW functions
    //-------------------------------------------------------------------------

    /// @notice Give back the current amount pending
    function ticketsToEndL1() public view returns (uint) {
        uint currentL1Id = maxRoundIdPerLevel[1];
        return ticketsPerL1 - _level1[currentL1Id].totalTickets;
    }

    function ticketsToEnd(uint _level) external view returns (uint) {
        if (_level == 0) return 0;
        if (_level == 1) return ticketsToEndL1();

        uint currentMaxRound = maxRoundIdPerLevel[_level];
        if (currentMaxRound == 0) currentMaxRound = 1;
        uint currentL1inPlay = maxRoundIdPerLevel[1];
        uint roundMultiplier = (10 ** (_level - 2)) * 20 * 1000;

        currentMaxRound = roundMultiplier * currentMaxRound;
        currentL1inPlay =
            1000 *
            currentL1inPlay +
            _level1[currentL1inPlay].totalTickets -
            ticketsPerL1;

        return currentMaxRound - currentL1inPlay;
    }

    function allRoundsParticipatedIn(
        address _user
    ) external view returns (uint[] memory roundsPlayed) {
        roundsPlayed = userParticipations[_user].participationsL1;
    }

    function ticketsL1OnRoundId(
        uint _roundId,
        address _user
    ) external view returns (uint) {
        return userTickets[_user][_roundId].tickets;
    }

    function totalRoundsToPlay() external view returns (uint) {
        return roundsToPlay.length;
    }

    function getAllL1Participants(uint level1Id) external view returns( address[] memory users, uint[] memory tickets){
        users = _level1[level1Id].users;
        tickets = _level1[level1Id].ticketsPerUser;
    }

    function getLevelRoundWinner(uint level, uint roundId) external view returns(address){

        // todo!!!!!
        return address(0);
    }
}
