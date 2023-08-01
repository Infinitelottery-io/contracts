// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/IWinnerHub.sol";
import "./interfaces/IDividendNFT.sol";
import "./interfaces/IWeeklyLottery.sol";
// TODO REMOVE TEST LIBRARY
import "forge-std/console2.sol";

error InfiniteLottery__NoRoundsToPlay();
error InfiniteLottery__MinimumTicketsNotReached(uint minTickets);
error InfiniteLottery__HighValue(uint valueSent);
error InfiniteLottery__InvalidWinnerHub();
error InfiniteLottery__InvalidDiscountLocker();
error InfiniteLottery__InvalidDividendNFT();
error InfiniteLottery__InvalidWeeklyLottery();
error InfiniteLottery__InvalidTeamWallet();
error InfiniteLottery__IncompleteSetup(
    address,
    address,
    address,
    address,
    address
);

contract InfiniteLottery is
    ILottery,
    VRFConsumerBaseV2,
    Ownable,
    ReentrancyGuard
{
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
        uint winnerL1Index;
        address winnerAddress;
    }
    struct UserParticipations {
        uint[] participationsL1;
        uint lastParticipation; // TODO add this to the buy tickets function
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
    mapping(address => bool) private minExcluded;
    mapping(uint _level => mapping(uint _id => UpperLevels))
        private _higherLevels;
    mapping(uint _round => Level1Participants) private _level1;
    mapping(address _user => UserParticipations) public userParticipations;
    mapping(address _user => mapping(uint _level1Id => UserRoundInfo))
        public userTickets;
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
    IDividendNFT public dividendNFT;
    IWeeklyLottery public weeklyDrawLottery;
    address public discountLocker;
    address public winnerDistribution;
    address public teamWallet;

    uint private bulkId = 0; // current id of the bulk of winner info to get
    uint public constant ticketsPerL1 = 1000;
    uint public constant l1Advancement = 20; // 20 rounds of L1 for a L2
    uint public constant upperAdvancement = 10; // 10 rounds of any upper level to the next level
    uint public immutable ticketPrice;
    uint public winnerPot = 30;
    uint public rollupPot = 30;
    uint public roiPot = 20;
    uint public dividendPot = 10;
    uint public referralPot = 5;
    uint public teamPot = 3;
    uint public weeklyPot = 2;
    uint public constant BASE_DISTRIBUTION = 100;
    uint public MINIMUM_TICKETS_PER_BUY = 10;
    uint public pendingBulkRequested;
    uint private cumulativeDiscount;
    uint private cumulativeDividends;
    uint private cumulativeTeam;
    uint private cumulativeWeekly;

    // VRF Stuff
    bytes32 private vrfHash;
    uint64 private subid;
    uint16 private minConfirmations = 3; // default
    uint32 private callbackGasLimit = 2_000_000; // todo NEED ABILITY TO CHANGE GAS LIMIT

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
    event NonWinsDistributed(uint indexed level, uint indexed roundId);
    event WinnerInfoSet(
        uint indexed level,
        uint indexed roundId,
        uint indexed level1,
        uint winnerNumber,
        address winnerAddress
    );

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
        uint _ticketPrice,
        uint64 _vrfSubId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrf = VRFCoordinatorV2Interface(_vrfCoordinator);
        // These only operate in BSC Mainnet and Testnet
        if (block.chainid == 56)
            vrfHash = 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04;
        else if (block.chainid == 97)
            vrfHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

        USDC = IERC20(_usdc);
        ticketPrice = _ticketPrice;
        subid = _vrfSubId;
    }

    //-------------------------------------------------------------------------
    //    External Functions
    //-------------------------------------------------------------------------
    function startLottery() external onlyOwner {
        if (
            teamWallet == address(0) ||
            discountLocker == address(0) ||
            address(dividendNFT) == address(0) ||
            address(winnerHub) == address(0) ||
            address(weeklyDrawLottery) == address(0)
        )
            revert InfiniteLottery__IncompleteSetup(
                teamWallet,
                discountLocker,
                address(dividendNFT),
                address(winnerHub),
                address(weeklyDrawLottery)
            );
        require(maxRoundIdPerLevel[1] == 0, "Already started");
        maxRoundIdPerLevel[1] = 1;
        emit LotteryStarted(block.timestamp);
    }

    function buyTickets(
        uint _ticketAmount,
        address _referral,
        bool allowPlay
    ) external {
        _buyTickets(_ticketAmount, _referral, msg.sender);
        if (allowPlay && roundsToPlay.length > 0) playRounds();
    }

    function buyTicketsForUser(
        uint _ticketAmount,
        address _referral,
        address _user,
        bool allowPlay
    ) external {
        _buyTickets(_ticketAmount, _referral, _user);
        if (allowPlay && roundsToPlay.length > 0) playRounds();
    }

    // This will be called by the contract itself to advance rounds internally
    // honestly this is mainly for testing purposes. But it's a good way to do it in case someone decides to
    // buy a lot of tickets from the get go.
    function playRounds() public nonReentrant {
        // make sure that there are rounds to play
        if (roundsToPlay.length == 0) revert InfiniteLottery__NoRoundsToPlay();
        uint requestNumbers;
        uint round1Pot = ticketsPerL1 * ticketPrice;

        WinnerInfo[] storage winnerChoose = winnerInfo[bulkId];
        // Start to loop through available rounds to play
        for (uint i = 0; i < roundsToPlay.length; i++) {
            uint currentL1Round = roundsToPlay[i];
            // We need to transfer out the roiOverflow
            // Distribute POT to next round and other users (?) OR do we do this after we have the winner tickets picked?
            Level1Participants storage level1 = _level1[currentL1Round];
            WinnerInfo memory winnerLog = WinnerInfo({
                level: 1,
                id: roundsToPlay[i],
                winnerAddress: address(0),
                winnerL1Index: 0,
                winnerNumber: 0
            });
            // Record where the info for the winner is stored
            level1.bulkId = bulkId;
            level1.winnerIndex = winnerChoose.length;
            // Distribute the pot of complete round and any superior completed rounds
            // Increase the amount of numbers to request in a single call to vrf.
            requestNumbers += distributeNonWinPot(
                round1Pot,
                1,
                currentL1Round,
                bulkId
            );
            if (level1.users.length == 1) {
                winnerLog.winnerAddress = level1.users[0];
                distributeWins(winnerLog.winnerAddress, round1Pot);
                emit WinnerInfoSet(
                    winnerLog.level,
                    winnerLog.id,
                    winnerLog.id,
                    winnerLog.winnerNumber,
                    winnerLog.winnerAddress
                );
            } else requestNumbers++;
            winnerChoose.push(winnerLog);
        }
        // Make a cumulative Non wins transfers
        transferOutNonWins();
        if (requestNumbers > 0) {
            pendingBulkRequested = requestNumbers;
            bulkIdToVrfRequestID[bulkId] = vrf.requestRandomWords(
                vrfHash,
                subid,
                minConfirmations,
                callbackGasLimit,
                uint32(requestNumbers)
            );
        } else {
            pendingBulkRequested = 0;
            // if bulkId => 0 then we can assume that no random request was made
            bulkIdToVrfRequestID[bulkId] = 0;
        }
        // Request the random numbers from the VRF and stores request ID tied to bulkId and vice versa
        vrfRequestToBulkId[bulkIdToVrfRequestID[bulkId]] = bulkId;
        // after this is called, then we can safely reset the array of rounds to play.
        // Increase BulkId count
        bulkId++;
        // reset the results array;
        roundsToPlay = new uint[](0);
    }

    function setMinimumTicketBuy(uint _newAmount) external onlyOwner {
        if (_newAmount > 100) revert InfiniteLottery__HighValue(_newAmount);
        emit SetNewMinimumTicketBuy(MINIMUM_TICKETS_PER_BUY, _newAmount);
        MINIMUM_TICKETS_PER_BUY = _newAmount;
    }

    function setWinnerHub(address _hub) external onlyOwner {
        if (_hub == address(0)) revert InfiniteLottery__InvalidWinnerHub();
        minExcluded[address(winnerHub)] = false;
        winnerHub = IWinnerHub(_hub);
        minExcluded[address(winnerHub)] = true;
        USDC.approve(_hub, type(uint).max); // max approval
    }

    function increaseHubApproval() external {
        USDC.approve(address(winnerHub), type(uint).max); // max approval
    }

    function setReferral(address _newReferral) external {}

    /**
     * @notice Sets the Address of the discount locker
     * @param _newLocker The address of the discount locker contract
     * @dev only owner and does not require approve since the locker only receives funds
     */
    function setDiscountLocker(address _newLocker) external onlyOwner {
        if (_newLocker == address(0) || discountLocker == _newLocker)
            revert InfiniteLottery__InvalidDiscountLocker();
        discountLocker = _newLocker;
    }

    /**
     * @notice Sets the Address of the dividend NFT
     * @param _newDividendNFT The address of the new dividend NFT contract
     * @dev only owner and requires USDC approval since the NFT contract needs to request funds from us.
     */
    function setDividendNFT(address _newDividendNFT) external onlyOwner {
        if (
            _newDividendNFT == address(0) ||
            address(dividendNFT) == _newDividendNFT
        ) revert InfiniteLottery__InvalidDividendNFT();

        minExcluded[address(dividendNFT)] = false;

        dividendNFT = IDividendNFT(_newDividendNFT);

        minExcluded[address(dividendNFT)] = true;

        USDC.approve(_newDividendNFT, type(uint).max); // max approval
    }

    /**
     * @notice Sets the Address of the weekly lottery
     * @param _newWeeklyDraw The address of the new weekly lottery contract
     * @dev only owner and requires USDC approval since the weekly lottery contract needs to request funds from us when adding to pot
     */
    function setWeeklyLottery(address _newWeeklyDraw) external onlyOwner {
        if (
            _newWeeklyDraw == address(0) ||
            address(weeklyDrawLottery) == _newWeeklyDraw
        ) revert InfiniteLottery__InvalidWeeklyLottery();
        weeklyDrawLottery = IWeeklyLottery(_newWeeklyDraw);
        USDC.approve(_newWeeklyDraw, type(uint).max); // max approval
    }

    function setTeamWalletAddress(address _newTeamWallet) external onlyOwner {
        if (_newTeamWallet == address(0) || teamWallet == _newTeamWallet)
            revert InfiniteLottery__InvalidTeamWallet();
        teamWallet = _newTeamWallet;
    }

    //-------------------------------------------------------------------------
    //    Internal Functions
    //-------------------------------------------------------------------------

    function fulfillRandomWords(
        uint requestId,
        uint256[] memory randomWords
    ) internal override {
        pendingBulkRequested = 0;
        //get the bulkId that belongs to this requestId
        uint _bulkId = vrfRequestToBulkId[requestId];
        WinnerInfo[] storage winnerChoose = winnerInfo[_bulkId];
        // get the winnerInfo array associated with bulkID and loop through it to select the winners
        uint totalWinners = winnerChoose.length;
        uint offset = 0;
        for (uint i = 0; i < totalWinners; i++) {
            WinnerInfo storage winner = winnerChoose[i];
            if (winner.winnerAddress != address(0)) {
                offset++;
                continue;
            }

            if (winner.level == 1) {
                _selectL1Winner(winner, winner.id, randomWords[i - offset]);
                uint pot = ticketsPerL1 * ticketPrice;
                distributeWins(winner.winnerAddress, pot);
                emit WinnerInfoSet(
                    winner.level,
                    winner.id,
                    winner.id,
                    winner.winnerNumber,
                    winner.winnerAddress
                );
                continue;
            }
            UpperLevels storage upperLevel = _higherLevels[winner.level][
                winner.id
            ];
            uint l1Index = upperLevel.maxL1 - upperLevel.minL1 + 1;
            console2.log(
                "uppers %s, min %s, l1Index %s",
                upperLevel.maxL1,
                upperLevel.minL1,
                l1Index
            );
            winner.winnerL1Index =
                (randomWords[i] % l1Index) +
                upperLevel.minL1; // select one level 1 as a winner

            l1Index = (randomWords[i] - winner.winnerL1Index);

            _selectL1Winner(winner, winner.winnerL1Index, l1Index);
            distributeWins(winner.winnerAddress, upperLevel.currentPot);
            emit WinnerInfoSet(
                winner.level,
                winner.id,
                winner.winnerL1Index,
                winner.winnerNumber,
                winner.winnerAddress
            );
        }
    }

    function _selectL1Winner(
        WinnerInfo storage _winnerInfo,
        uint level1Id,
        uint _winnerNumber
    ) internal {
        uint winnerIndex = _winnerNumber % ticketsPerL1;
        _winnerInfo.winnerNumber = winnerIndex;
        Level1Participants storage level1 = _level1[level1Id];
        for (uint j = 0; j < level1.users.length; j++) {
            if (level1.ticketsPerUser[j] < winnerIndex) {
                winnerIndex -= level1.ticketsPerUser[j];
                continue;
            }
            _winnerInfo.winnerAddress = level1.users[j];
            break;
        }
    }

    //-------------------------------------------------------------------------
    //    Private Functions
    //-------------------------------------------------------------------------

    function _buyTickets(
        uint _ticketAmount,
        address _referral,
        address _user
    ) private nonReentrant {
        require(maxRoundIdPerLevel[1] > 0, "Not started");
        if (!minExcluded[msg.sender] && _ticketAmount < MINIMUM_TICKETS_PER_BUY)
            revert InfiniteLottery__MinimumTicketsNotReached(
                MINIMUM_TICKETS_PER_BUY
            );
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
        do {
            userPlaying = userTickets[_user][level1Played];
            (leftovers, level1Played, roiTickets) = _createTickets(
                roiTickets,
                level1Played,
                roiTickets >= 5,
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
        } while (roiTickets > 0);

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
     *   @param _user The user that gets the tickets
     *   @param userPlaying STORAGE user Round info
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
            roiTickets = (amount * roiPot) / BASE_DISTRIBUTION;
            roiLeftOver = (amount * ticketPrice * roiPot) / BASE_DISTRIBUTION;
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

    /**
     * @notice Distributes the winnings to the winner and the referral
     * @param _winner Address of user that won
     * @param pot The total pot of the round and level
     */
    function distributeWins(address _winner, uint pot) private {
        address ref = userParticipations[_winner].referral;
        uint refAmount = (pot * referralPot) / BASE_DISTRIBUTION;
        uint reward = (pot * winnerPot) / BASE_DISTRIBUTION;

        if (ref == address(0)) ref = teamWallet;

        winnerHub.distributeWinnings(_winner, ref, reward, refAmount);
    }

    /**
     * @notice This function distributes the non-win pot to the different pots as well as returns the amount of additional randomness requests that need to be fulfilled.
     * @param pot The pot of the current level and round to be distributed
     * @param currentLevel The current level being distributed
     * @param currentLevelId The current ID of the level being distributed
     * @param _bulkId The id of the bulk randomness request that needs to be fulfilled.
     * @return additionalRequests The amount of additional requests that need to be fulfilled
     */
    function distributeNonWinPot(
        uint pot,
        uint currentLevel,
        uint currentLevelId,
        uint _bulkId
    ) private returns (uint additionalRequests) {
        // DISTRIBUTE ROI
        uint potToDistribute = (pot * roiPot) / BASE_DISTRIBUTION;
        uint forNextLevel = 20;

        // If current Level is 1, roi distribution already happened in the form of tickets
        if (currentLevel > 1) {
            //USDC.transfer(discountLocker, potToDistribute);
            cumulativeDiscount += potToDistribute;
            forNextLevel = 10;
        }
        // DISTRIBUTE DIVIDENDS
        potToDistribute = (pot * dividendPot) / BASE_DISTRIBUTION;
        // dividendNFT.distributeDividends(potToDistribute);
        cumulativeDividends += potToDistribute;
        // DISTRIBUTE TEAM
        potToDistribute = (pot * teamPot) / BASE_DISTRIBUTION;
        cumulativeTeam += potToDistribute;
        // USDC.transfer(teamWallet, potToDistribute);
        // DISTRIBUTE WEEKLY POT
        potToDistribute = (pot * weeklyPot) / BASE_DISTRIBUTION;
        cumulativeWeekly += potToDistribute;
        // weeklyDrawLottery.addToPot(potToDistribute);
        // DISTRIBUTE Roll UP POT
        potToDistribute = (pot * rollupPot) / BASE_DISTRIBUTION;

        uint nextLevel = currentLevel + 1;

        uint nextLevelId = (currentLevelId - 1) / forNextLevel + 1;
        UpperLevels storage nextLevelInfo = _higherLevels[nextLevel][
            nextLevelId
        ];
        nextLevelInfo.currentPot += potToDistribute;
        if (nextLevelInfo.minL1 == 0) {
            if (currentLevel == 1) nextLevelInfo.minL1 = currentLevelId;
            else
                nextLevelInfo.minL1 = _higherLevels[currentLevel][
                    currentLevelId
                ].minL1;
            maxRoundIdPerLevel[nextLevel] = nextLevelId;
        }

        emit NonWinsDistributed(currentLevel, currentLevelId);
        if (currentLevelId % forNextLevel == 0) {
            maxRoundIdPerLevel[nextLevel] = nextLevelId + 1;
            potToDistribute = nextLevelInfo.currentPot;
            nextLevelInfo.bulkId = _bulkId;
            if (currentLevel == 1) nextLevelInfo.maxL1 = currentLevelId;
            else
                nextLevelInfo.maxL1 = _higherLevels[currentLevel][
                    currentLevelId
                ].maxL1;
            WinnerInfo memory winnerLog = WinnerInfo({
                level: nextLevel,
                id: nextLevelId,
                winnerAddress: address(0),
                winnerL1Index: 0,
                winnerNumber: 0
            });
            winnerInfo[bulkId].push(winnerLog);

            additionalRequests = 1;
            additionalRequests += distributeNonWinPot(
                potToDistribute,
                nextLevel,
                nextLevelId,
                _bulkId
            );
        }
    }

    function transferOutNonWins() private {
        if (cumulativeDiscount > 0)
            USDC.transfer(discountLocker, cumulativeDiscount);
        if (cumulativeDividends > 0)
            dividendNFT.distributeDividends(cumulativeDividends);
        if (cumulativeTeam > 0) USDC.transfer(teamWallet, cumulativeTeam);
        if (cumulativeWeekly > 0) weeklyDrawLottery.addToPot(cumulativeWeekly);

        cumulativeDiscount = 0;
        cumulativeDividends = 0;
        cumulativeTeam = 0;
        cumulativeWeekly = 0;
    }

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

    function getAllL1Participants(
        uint level1Id
    ) external view returns (address[] memory users, uint[] memory tickets) {
        users = _level1[level1Id].users;
        tickets = _level1[level1Id].ticketsPerUser;
    }

    function getRoiLeftOver(uint level1Id) external view returns (uint) {
        return _level1[level1Id].roiOverflow;
    }

    function getLevel1Info(
        uint _roundId
    ) external view returns (Level1Participants memory) {
        return _level1[_roundId];
    }

    function getLevelRoundWinner(
        uint level,
        uint roundId
    ) external view returns (address) {
        uint _bulkId;
        uint winnerIndex;
        if (level == 1) {
            _bulkId = _level1[roundId].bulkId;
            winnerIndex = _level1[roundId].winnerIndex;
        } else {
            _bulkId = _higherLevels[level][roundId].bulkId;
            winnerIndex = _higherLevels[level][roundId].winnerIndex;
        }
        return winnerInfo[_bulkId][winnerIndex].winnerAddress;
    }
}
