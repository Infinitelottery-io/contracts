// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../contracts/Lottery.sol";
import "../contracts/WinnerHub.sol";
import "../contracts/DividendsNFT.sol";
import "../contracts/DiscountBooth.sol";
import "../contracts/ReferralNFT.sol";
import "../contracts/WeeklyLottery.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Script.sol";

contract DeployInfiniteEcosystem is Script {
    function run() external {
        IERC20 usdc = IERC20(0xBe6DDd788b563807A0E60fE4EA6c06149c049735); // TEST BUSD DO NOT USE IN PRODUCTION
        address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
        address teamWallet = 0x7Ff20b4E1Ad27C5266a929FC87b00F5cCB456374;
        uint256 deployerPrivate = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivate);
        InfiniteLottery lottery = new InfiniteLottery(
            vrfCoordinator,
            address(usdc),
            1 ether,
            3162
        );
        lottery.setTeamWalletAddress(teamWallet);
        lottery.setDiscountLocker(
            address(new DiscountBooth(address(lottery), address(usdc), 5_00))
        );
        IFL_ReferralNFT refNFT = new IFL_ReferralNFT(
            "pending",
            teamWallet,
            address(usdc)
        );
        lottery.setWinnerHub(
            address(
                new WinnerHub(address(usdc), address(refNFT), address(lottery))
            )
        );
        IFL_DividendNFT dividendNFT = new IFL_DividendNFT(address(usdc));
        lottery.setDividendNFT(address(dividendNFT));
        lottery.setWeeklyLottery(address(new WeeklyLottery(address(usdc))));
        vm.stopBroadcast();
    }
}
