//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../contracts/DividendsNFT.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "forge-std/Test.sol";

contract Test_DivNFT is Test {
    IFL_DividendNFT public divNFT;
    ERC20PresetFixedSupply public USDC;
    address public multiSig = makeAddr("multiSig");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        USDC = new ERC20PresetFixedSupply(
            "USDC",
            "USDC",
            1_000_000 ether,
            address(this)
        );
        divNFT = new IFL_DividendNFT(address(USDC), multiSig);
        USDC.transfer(user1, 1000 ether);
        USDC.transfer(user2, 1000 ether);
        vm.prank(user1);
        USDC.approve(address(divNFT), 1000 ether);
        vm.prank(user1);
        USDC.approve(address(divNFT), 1000 ether);

        USDC.approve(address(divNFT), 1_000_000 ether);
    }

    function test_mint() public {
        vm.prank(user1);

        divNFT.mint(user1, 2);

        assertEq(divNFT.balanceOf(user1), 2);
        assertEq(divNFT.totalSupply(), 2);

        USDC.transfer(user2, 100_000 ether);
        vm.startPrank(user2);
        USDC.approve(address(divNFT), 100_000 ether);
        vm.expectRevert();
        divNFT.mint(user2, 350);
        vm.stopPrank();
        assertTrue(false);
    }

    function test_claimDivs() public {
        vm.prank(user1);
        divNFT.mint(user1, 2);

        divNFT.distributeDividends(200 ether);

        uint[] memory idsToClaim = new uint[](2);
        idsToClaim[0] = 1;
        idsToClaim[1] = 2;

        vm.prank(user2);
        vm.expectRevert();
        divNFT.claimDividends(idsToClaim);

        uint initU1Balance = USDC.balanceOf(user1);

        vm.prank(user1);
        divNFT.claimDividends(idsToClaim);

        assertEq(USDC.balanceOf(user1), initU1Balance + 200 ether);

        vm.startPrank(user1);
        vm.expectRevert();
        divNFT.claimDividends(idsToClaim);
        idsToClaim = new uint[](1);
        idsToClaim[0] = 1;
        vm.expectRevert();
        divNFT.claimDividends(idsToClaim);
        idsToClaim[0] = 2;
        vm.expectRevert();
        divNFT.claimDividends(idsToClaim);
    }

    function test_claimDivs_single() public {
        vm.prank(user1);
        divNFT.mint(user1, 2);

        divNFT.distributeDividends(200 ether);

        uint[] memory idsToClaim = new uint[](1);
        idsToClaim[0] = 1;

        vm.prank(user2);
        vm.expectRevert();
        divNFT.claimDividends(idsToClaim);

        uint initU1Balance = USDC.balanceOf(user1);

        vm.prank(user1);
        divNFT.claimDividends(idsToClaim);

        assertEq(USDC.balanceOf(user1), initU1Balance + 100 ether);

        idsToClaim[0] = 2;
        vm.prank(user1);
        divNFT.claimDividends(idsToClaim);
        assertEq(USDC.balanceOf(user1), initU1Balance + 200 ether);
    }
}
