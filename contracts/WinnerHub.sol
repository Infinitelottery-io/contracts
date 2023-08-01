//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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

contract WinnerHub is ReentrancyGuard, Ownable, IWinnerHub {
    //-------------------------------------------------------------------------
    //    State Variables
    //-------------------------------------------------------------------------
    mapping(address _winner => uint _winAmount) public winnings;
    mapping(address _referrer => uint _refAmount) public referrals;

    IERC20 public USDC;
    // @audit-issue Check if 1 or multiple contracts will be used
    IERC721 public DividendNFT;
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
    constructor(address _usdc, address _dividendNFT, address _lottery) {
        USDC = IERC20(_usdc);
        DividendNFT = IERC721(_dividendNFT);
        Lottery = ILottery(_lottery);
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

    /**
     * @notice Claim referral rewards
     * @dev is msg.sender has a Dividend NFT then we can skip the burning of IFL
     */
    function claimReferral() external nonReentrant {
        uint amountToClaim = referrals[msg.sender];
        referrals[msg.sender] = 0;
        bool succ;

        //TODO pending to check referral logic
        // 10% of the winnings will be for buy tickets
        succ = USDC.transfer(msg.sender, amountToClaim);
        if (!succ) revert WinnerHub__RefTransferError();
        emit ClaimReferrerWinnings(msg.sender, amountToClaim);
    }

    function updateLottery(address _lottery) external onlyOwner {
        if (address(_lottery) != address(0))
            revert WinnerHub__LotteryAlreadySet();
        if (_lottery == address(0)) revert WinnerHub__InvalidLotteryAddress();
        Lottery = ILottery(_lottery);
    }

    function updateNFTAddress(address _nft) external onlyOwner {
        if (address(_nft) != address(0)) revert WinnerHub__NFTAlreadySet();
        if (_nft == address(0)) revert WinnerHub__InvalidNFTAddress();
        DividendNFT = IERC721(_nft);
    }
}
