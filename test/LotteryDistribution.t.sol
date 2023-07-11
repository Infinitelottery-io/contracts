// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../contracts/Lottery.sol";
import "../contracts/mocks/MockToken.sol";
import "../contracts/mocks/MockVRF.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";

contract TestLotteryDistribution is Test {
    InfiniteLottery lottery;

    VRFCoordinatorV2Mock vrf;
    IERC20 usdc;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address referral1 = makeAddr("referral1");

    function setUp() public {
        usdc = new TestToken();
        vrf = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);
        lottery = new InfiniteLottery(address(vrf), address(usdc), 1 ether);

        usdc.transfer(user1, 100 ether);
        usdc.transfer(user2, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.prank(user1);
        usdc.approve(address(lottery), 100 ether);
        vm.prank(user2);
        usdc.approve(address(lottery), 100 ether);

        lottery.startLottery();
    }

    function test_buyTickets() public {
        vm.prank(user1);
        lottery.buyTickets(10, referral1);

        assertEq(lottery.ticketsL1OnRoundId(1, user1), 10);
    }
}
