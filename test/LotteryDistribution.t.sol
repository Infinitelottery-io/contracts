// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../contracts/Lottery.sol";
import "../contracts/WinnerHub.sol";
import "../contracts/WeeklyLottery.sol";
import "../contracts/mocks/MockToken.sol";
import "../contracts/mocks/MockVRF.sol";
import "../contracts/mocks/MockNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

contract TestLotteryDistribution is Test {
    InfiniteLottery lottery;

    VRFCoordinatorV2Mock vrf;
    IERC20 usdc;
    MockNft nft;
    WinnerHub hub;
    WeeklyLottery weekly;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    address user6 = makeAddr("user6");
    address user7 = makeAddr("user7");
    address user8 = makeAddr("user8");
    address user9 = makeAddr("user9");
    address user0 = makeAddr("user0");
    address team = makeAddr("team");
    address referral1 = makeAddr("referral1");

    address locker = makeAddr("locker");

    //----------------------------------------------------
    // Events
    //----------------------------------------------------
    event NonWinsDistributed(uint indexed level, uint indexed roundId);
    event WinnerInfoSet(
        uint indexed level,
        uint indexed roundId,
        uint indexed level1,
        uint winnerNumber,
        address winnerAddress
    );

    function setUp() public {
        usdc = new TestToken();
        vrf = new VRFCoordinatorV2Mock(0.1 ether, 141 gwei);
        nft = new MockNft(address(usdc));
        weekly = new WeeklyLottery(address(usdc));
        lottery = new InfiniteLottery(address(vrf), address(usdc), 1 ether, 1);
        hub = new WinnerHub(address(usdc), address(nft), address(lottery));

        lottery.setDividendNFT(address(nft));
        lottery.setDiscountLocker(locker);
        lottery.setWinnerHub(address(hub));
        lottery.setTeamWalletAddress(team);
        lottery.setWeeklyLottery(address(weekly));

        vrf.createSubscription();
        vrf.fundSubscription(1, 100 ether);
        vrf.addConsumer(1, address(lottery));

        usdc.transfer(user1, 10000 ether);
        usdc.transfer(user2, 10000 ether);
        usdc.transfer(user3, 10000 ether);
        usdc.transfer(user4, 10000 ether);
        usdc.transfer(user5, 10000 ether);
        usdc.transfer(user6, 10000 ether);
        usdc.transfer(user7, 10000 ether);
        usdc.transfer(user8, 10000 ether);
        usdc.transfer(user9, 10000 ether);
        usdc.transfer(user0, 10000 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.prank(user1);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user2);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user3);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user3);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user4);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user5);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user6);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user7);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user8);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user9);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user0);
        usdc.approve(address(lottery), 10000 ether);

        lottery.startLottery();
    }

    function test_manual_distribution_only_L1_single() public {
        // Need to buy enough tickets between 2 or more users to pass a round
        vm.prank(user1);
        lottery.buyTickets(500, referral1, false);
        vm.prank(user2);
        lottery.buyTickets(500, referral1, false);
        vm.prank(user3);
        lottery.buyTickets(500, referral1, false);

        // Play for 1 round
        assertEq(lottery.totalRoundsToPlay(), 1);
        vm.expectEmit();
        emit NonWinsDistributed(1, 1);
        lottery.playRounds();
        assertEq(usdc.balanceOf(locker), 0);
        assertEq(usdc.balanceOf(address(nft)), 100 ether);
        assertEq(usdc.balanceOf(team), 30 ether);
        assertEq(usdc.balanceOf(address(weekly)), 20 ether);
        /// fulfill Random number requested
        uint[] memory randomNumbers = new uint[](1);
        randomNumbers[0] = 7894384631; // This should be user2 as a winner last 3 digits select a winner for a L1
        vm.expectEmit();
        emit WinnerInfoSet(1, 1, 1, 631, user2);
        vrf.fulfillRandomWordsWithOverride(1, address(lottery), randomNumbers);
        /// Check winner distribution
        assertEq(hub.winnings(user2), 300 ether);
        assertEq(hub.referrals(referral1), 50 ether);
    }

    function test_automatic_distribution_L1_1() public {
        vm.prank(user1);
        lottery.buyTickets(500, referral1, true);
        // Round is played here
        vm.prank(user2);
        vm.expectEmit();
        emit NonWinsDistributed(1, 1);
        lottery.buyTickets(500, referral1, true);

        /// fulfill Random number requested
        uint[] memory randomNumbers = new uint[](1);
        randomNumbers[0] = 7894384631; // This should be user2 as a winner last 3 digits select a winner for a L1
        vm.expectEmit();
        emit WinnerInfoSet(1, 1, 1, 631, user2);
        vrf.fulfillRandomWordsWithOverride(1, address(lottery), randomNumbers);
        /// Check winner distribution
        assertEq(hub.winnings(user2), 300 ether);
        assertEq(hub.referrals(referral1), 50 ether);
    }

    function test_manual_distribution_only_L1_multiple_5() public {
        // Need to buy enough tickets between 2 or more users to pass a round
        vm.prank(user1);
        lottery.buyTickets(1500, referral1, false);
        vm.prank(user2);
        lottery.buyTickets(1500, referral1, false);
        vm.prank(user3);
        lottery.buyTickets(1500, referral1, false);
        // // Play for 1 round
        assertEq(lottery.totalRoundsToPlay(), 5);
        // request 5 rounds
        lottery.playRounds();

        /// fulfill Random number requested
        uint[] memory randomNumbers = new uint[](4);
        randomNumbers[0] = 7894384631; // This should be user2 as a winner last 3 digits select a winner for a L1
        randomNumbers[1] = 0; // This should be user2 as a winner last 3 digits select a winner for a L1
        randomNumbers[2] = 7894384631300; // This should be user2 as a winner last 3 digits select a winner for a L1
        randomNumbers[3] = 7894384631400; // This should be user2 as a winner last 3 digits select a winner for a L1
        vm.expectEmit();
        emit WinnerInfoSet(1, 2, 2, 631, user2);
        vrf.fulfillRandomWordsWithOverride(1, address(lottery), randomNumbers);
        /// Check winner distribution
        assertEq(hub.winnings(user1), 300 ether * 2);
        assertEq(hub.winnings(user2), 300 ether * 2);
        assertEq(hub.winnings(user3), 300 ether);
    }

    function test_automatic_distribution_only_L1_multiple_5() public {
        // Need to buy enough tickets between 2 or more users to pass a round
        vm.startPrank(user1);
        for (uint i = 0; i < 50; i++) lottery.buyTickets(20, referral1, true);
        lottery.buyTickets(500, referral1, true);
        vm.stopPrank();
        vm.prank(user2);
        lottery.buyTickets(1500, referral1, true);

        uint[] memory randomNumbers = new uint[](1);
        randomNumbers[0] = 100; // This should be 1 ) user1 | 3) user2;
        vrf.fulfillRandomWordsWithOverride(1, address(lottery), randomNumbers);

        vm.prank(user3);
        lottery.buyTickets(1500, referral1, true);
        // // Play for 1 round
        // randomNumbers = new uint[](1);
        randomNumbers[0] = 100; // This should be 1 ) user1 | 3) user2;
        vrf.fulfillRandomWordsWithOverride(2, address(lottery), randomNumbers);
        /// fulfill Random number requested
        /// Check winner distribution
        assertEq(hub.winnings(user1), 300 ether * 2);
        assertEq(hub.winnings(user2), 300 ether * 2);
        assertEq(hub.winnings(user3), 300 * 1 ether);
    }

    function test_distribution_L1AndL2_manual() public {
        vm.prank(user1);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user2);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user3);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user4);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user5);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user6);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user7);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user8);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user9);
        lottery.buyTickets(1650, referral1, false);
        vm.prank(user0);
        lottery.buyTickets(1650, referral1, false);

        lottery.playRounds();

        uint roundsToPlay = lottery.totalRoundsToPlay();

        uint[] memory randomNumbers = new uint[](roundsToPlay);
        for (uint i = 0; i < roundsToPlay; i++) {
            randomNumbers[i] = 300;
        }
        vrf.fulfillRandomWordsWithOverride(1, address(lottery), randomNumbers);
    }

    function randomnessRequestHelper(
        uint requestID
    ) public returns (uint nextRequestId) {
        uint roundsToPlay = lottery.pendingBulkRequested();
        if (roundsToPlay == 0) {
            return requestID;
        }
        uint[] memory randomNumbers = new uint[](0);
        vrf.fulfillRandomWordsWithOverride(
            requestID,
            address(lottery),
            randomNumbers
        );
        return requestID + 1;
    }

    function test_automatic_distribution_L1AndL2() public {
        uint request = 1;

        vm.prank(user1);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user2);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user3);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user4);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user5);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user6);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user7);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user8);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user9);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        vm.prank(user0);
        lottery.buyTickets(1650, referral1, true);
        request = randomnessRequestHelper(request);
        assertEq(lottery.maxRoundIdPerLevel(4), 0);
        assertEq(lottery.maxRoundIdPerLevel(3), 1);
        assertEq(lottery.maxRoundIdPerLevel(2), 2);
        assertEq(lottery.maxRoundIdPerLevel(1), 21);
    }

    function test_automatic_distribution_L1toL3() public {}
}
