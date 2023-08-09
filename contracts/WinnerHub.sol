//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/IWinnerHub.sol";

//-------------------------------------------------------------------------
//    Errors
//-------------------------------------------------------------------------
error WinnerHub__NoWinnings();
error WinnerHub__RefTransferError();
error WinnerHub__IFLTransferError();
error WinnerHub__InvalidLotteryAddress();
error WinnerHub__LotteryAlreadySet();
error WinnerHub__NFTAlreadySet();
error WinnerHub__InvalidNFTAddress();
error WinnerHub__NoReferralNFTDetected();

contract WinnerHub is ReentrancyGuard, Ownable, IWinnerHub {
    //-------------------------------------------------------------------------
    //    State Variables
    //-------------------------------------------------------------------------
    mapping(address _winner => uint _winAmount) public winnings;
    mapping(address _referrer => uint _refAmount) public referrals;

    IERC20 public USDC;
    // @audit-issue Check if 1 or multiple contracts will be used
    IERC1155 public ReferralNFT;
    ILottery public Lottery;
    //-------------------------------------------------------------------------
    //    Events
    //-------------------------------------------------------------------------
    event ClaimReferrerWinnings(address indexed referral, uint indexed amount);
    event ClaimWinnings(address indexed winner, uint indexed amount);
    event ReceivedWinnings(
        address indexed winner,
        address indexed referrer,
        uint winAmount,
        uint refAmount
    );

    //-------------------------------------------------------------------------
    //    Constructor
    //-------------------------------------------------------------------------
    constructor(address _usdc, address _referralNFT, address _lottery) {
        USDC = IERC20(_usdc);
        ReferralNFT = IERC1155(_referralNFT);
        Lottery = ILottery(_lottery);
        USDC.approve(_lottery, type(uint256).max);
    }

    //-------------------------------------------------------------------------
    //    External Functions
    //-------------------------------------------------------------------------
    function distributeWinnings(
        address _winner,
        address _referral,
        uint _winAmount,
        uint _refAmount
    ) external nonReentrant {
        if (_winAmount + _refAmount == 0) revert WinnerHub__NoWinnings();

        winnings[_winner] += _winAmount;
        // Since the condition to claim is to BURN 10% in IFL it doesn't matter the level to claim
        if (_referral != address(0) && _refAmount > 0) {
            referrals[_referral] += _refAmount;
        }

        // Since this is ERC20 it'll revert if the sender doesn't have enough balance or allowance
        USDC.transferFrom(msg.sender, address(this), _winAmount + _refAmount);
        emit ReceivedWinnings(_winner, _referral, _winAmount, _refAmount);
    }

    function claimWinner() external nonReentrant {
        uint winAmount = winnings[msg.sender];
        if (winAmount == 0) revert WinnerHub__NoWinnings();

        winnings[msg.sender] = 0;
        USDC.transfer(msg.sender, winAmount);
        emit ClaimWinnings(msg.sender, winAmount);
    }

    function claimReferral() external nonReentrant {
        uint amountToClaim = referrals[msg.sender];
        if (amountToClaim == 0) revert WinnerHub__NoWinnings();
        referrals[msg.sender] = 0;
        bool succ;

        //Check referral logic
        // check referral has referral NFT
        if (ReferralNFT.balanceOf(msg.sender, 1) == 0)
            revert WinnerHub__NoReferralNFTDetected();
        // 10% of the winnings will be for buy tickets
        uint ticketsToBuy = amountToClaim / 10;
        amountToClaim -= ticketsToBuy;
        ticketsToBuy /= 1 ether;
        Lottery.buyTicketsForUser(ticketsToBuy, address(0), msg.sender, false);

        succ = USDC.transfer(msg.sender, amountToClaim);
        if (!succ) revert WinnerHub__RefTransferError();
        emit ClaimReferrerWinnings(msg.sender, amountToClaim);
    }

    function updateLottery(address _lottery) external onlyOwner {
        if (address(_lottery) != address(0))
            revert WinnerHub__LotteryAlreadySet();
        if (_lottery == address(0)) revert WinnerHub__InvalidLotteryAddress();
        USDC.approve(address(Lottery), 0);
        Lottery = ILottery(_lottery);
        USDC.approve(_lottery, type(uint256).max);
    }

    function updateNFTAddress(address _nft) external onlyOwner {
        if (address(_nft) != address(0)) revert WinnerHub__NFTAlreadySet();
        if (_nft == address(0)) revert WinnerHub__InvalidNFTAddress();
        ReferralNFT = IERC1155(_nft);
    }
}
