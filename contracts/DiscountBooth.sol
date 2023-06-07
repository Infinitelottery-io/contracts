//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILottery.sol";

error DiscountBooth__InvalidLotteryAddress();
error DiscountBooth__InvalidDiscountAmount();
error DiscountBooth__InvalidUSDCAddress();
error DiscountBooth__InsufficientUSDCBalance();

contract DiscountBooth is Ownable, ReentrancyGuard {
    //-------------------------------------------------------------------------
    //    State Variables
    //-------------------------------------------------------------------------
    IERC20 public USDC;
    ILottery public lottery;
    uint public totalTicketsBought;
    uint public totalDiscountsGiven;
    uint public discountAmount;
    uint public constant DISCOUNT_BASE = 10000; // 100.00 Uses 2 decimals just in case;

    //-------------------------------------------------------------------------
    //    Events
    //-------------------------------------------------------------------------
    event DiscountApplied(address indexed buyer, uint ticketsBought, uint indexed usdcAmountUsed);
    event UpdatedLottery(address indexed prevLottery, address indexed newLottery);
    event UpdatedDiscountAmount(uint indexed prevDiscound, uint indexed newDiscountAmount);
    //-------------------------------------------------------------------------
    //    Modifiers
    //-------------------------------------------------------------------------
    modifier isValidLottery(address _lottery) {
      if(_lottery == address(0))
        revert DiscountBooth__InvalidLotteryAddress();
      try ILottery(_lottery).ticketPrice() returns(uint _price) {
        if(_price < 0.5 ether)
          revert DiscountBooth__InvalidLotteryAddress();
        _;
      }
      catch{
        revert DiscountBooth__InvalidLotteryAddress();
      }
    }

    modifier isValidDiscountAmount(uint _amount, bool _constructor){
      if(_amount > DISCOUNT_BASE || (_amount < 100 && _constructor))
          revert DiscountBooth__InvalidDiscountAmount();
      _;
    }
    //-------------------------------------------------------------------------
    //    CONSTRUCTOR
    //-------------------------------------------------------------------------
    constructor(address _lottery, address _usdc, uint _discount) isValidLottery(_lottery) isValidDiscountAmount(_discount, true){
        
        if(_usdc == address(0))
          revert DiscountBooth__InvalidUSDCAddress();

        lottery = ILottery(_lottery);
        USDC = IERC20(_usdc);
        USDC.approve(_lottery, type(uint).max); // approve ALL THE USDC TO THE LOTTERY
        discountAmount = _discount;
    }


    //-------------------------------------------------------------------------
    //    External Functions
    //-------------------------------------------------------------------------

    function buyTicketsAtDiscount(uint ticketsToBuy, address _referral) external nonReentrant{
        uint ticketPrice = lottery.ticketPrice();
        uint totalCost = ticketPrice * ticketsToBuy;
        uint discount = totalCost * discountAmount / DISCOUNT_BASE;
        // Make sure we have enough funds to cover the discount;
        if(USDC.balanceOf(address(this)) < discount)
          revert DiscountBooth__InsufficientUSDCBalance();
        // Update Global vars
        totalTicketsBought += ticketsToBuy;
        totalDiscountsGiven += discount;
        
        uint costWithDiscount = totalCost - discount;
        USDC.transferFrom(msg.sender, address(this), costWithDiscount);
        emit DiscountApplied(msg.sender, ticketsToBuy, costWithDiscount);
        lottery.buyTicketsForUser(ticketsToBuy, _referral, msg.sender);
    }

    /// @notice Update the Lottery address in case of a redeploy
    /// @param _lottery The address of the new lottery
    function updateLottery(address _lottery) external onlyOwner isValidLottery(_lottery){
        // remove USDc approval from old lottery
        USDC.approve(address(lottery), 0);
        emit UpdatedLottery(address(lottery), _lottery);
        lottery = ILottery(_lottery);
        // approve USDC to new lottery
        USDC.approve(address(lottery), type(uint).max);
    }

    /**
     * @notice Updates the discount amount
     * @param _newDiscount The new discount amount to be set
     * @dev The discount amount is a percentage of the ticket price that will be discounted
     *      The discount amount is represented in basis points (10000 = 100.00%)
     *      The discount amount can't be greater than 100% (10000)
     */
    function updateDiscountAmount(uint _newDiscount) external onlyOwner isValidDiscountAmount(_newDiscount, false){
      emit UpdatedDiscountAmount(discountAmount, _newDiscount);
      discountAmount = _newDiscount;
    }
}