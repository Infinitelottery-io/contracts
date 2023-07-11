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
    address team = makeAddr("team");
    address referral1 = makeAddr("referral1");

    address locker = makeAddr("locker");

    //----------------------------------------------------
    // Events
    //----------------------------------------------------
    event NonWinsDistributed(uint indexed level, uint indexed roundId);

    function setUp() public {
        usdc = new TestToken();
        vrf = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);
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
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.prank(user1);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user2);
        usdc.approve(address(lottery), 10000 ether);
        vm.prank(user3);
        usdc.approve(address(lottery), 10000 ether);

        lottery.startLottery();
    }

    function test_distribution_only_L1_manual_before_winner() public {
        // Need to buy enough tickets between 2 or more users to pass a round
        vm.prank(user1);
        lottery.buyTickets(500, referral1);
        vm.prank(user2);
        lottery.buyTickets(500, referral1);
        vm.prank(user3);
        lottery.buyTickets(500, referral1);

        // Play for 1 round
        assertEq(lottery.totalRoundsToPlay(), 1);
        vm.expectEmit();
        emit NonWinsDistributed(1, 1);
        lottery.playRounds();

        /// fulfill Random number requested

        /// Check winner distribution
    }

    function test_distribution_after_winner_L1_only() public {}

    function test_distribution_L1AndL2_manual_before_winner() public {}

    function test_distribution_L1toL3_manual_before_winner() public {}

    function test_automatic_distribution_L1() public {}

    function test_automatic_distribution_L1AndL2() public {}

    function test_automatic_distribution_L1toL3() public {}
}
