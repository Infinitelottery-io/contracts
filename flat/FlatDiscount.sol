//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

interface ILottery {
    /// @notice This function buys tickets for user for the current level 1.
    /// @param _ticketAmount the amount of tickets to buy
    /// @param _referral the address of the wallet who referred this addres. Can only be set once and it's set forever
    /// @dev extra things that this does:
    ///         - Request winner for level 1 (when it ends)
    ///         - Request winner for higher levels (when it applies)
    function buyTickets(
        uint _ticketAmount,
        address _referral,
        bool autoplay
    ) external;

    /// @notice This function works the same as the previous buyTickets function except the tickets are approved to a user in particular
    /// @param _ticketAmount the amount of tickets to buy
    /// @param _referral the address of the wallet who referred this addres. Can only be set once and it's set forever
    /// @param _user The user that will receive the tickets
    /// @dev Does the same extra steps as prev buyTickets function
    function buyTicketsForUser(
        uint _ticketAmount,
        address _referral,
        address _user,
        bool autoplay
    ) external;

    /// @notice returns the current price of a ticket
    function ticketPrice() external view returns (uint);

    /// @notice returns the amount of tickets needed for the next Level1 to be over;
    /// @return amount of tickets
    function ticketsToEndL1() external view returns (uint);

    /// @notice returns the amount of tickets for the next _level to be over
    /// @param _level The level to query
    /// @return amount of tickets
    function ticketsToEnd(uint _level) external view returns (uint);

    /// @notice starts the Lottery
    function startLottery() external;

    /// @notice sets a new Minimum Ticket buy amount
    /// @param _newAmount the amount of tickets that the minimum will be
    function setMinimumTicketBuy(uint _newAmount) external;
}

error DiscountBooth__InvalidLotteryAddress();
error DiscountBooth__InvalidDiscountAmount();
error DiscountBooth__InvalidUSDCAddress();
error DiscountBooth__InsufficientUSDCBalance();
error DiscountBooth__InvalidDiscount();

contract DiscountBooth is Ownable, ReentrancyGuard {
    //-------------------------------------------------------------------------
    //    State Variables
    //-------------------------------------------------------------------------
    IERC20 public USDC;
    ILottery public lottery;
    uint public totalTicketsBought;
    uint public totalDiscountsGiven;
    uint public discountAmount;
    uint public constant DISCOUNT_BASE = 100_00; // 100.00 Uses 2 decimals just in case;

    //-------------------------------------------------------------------------
    //    Events
    //-------------------------------------------------------------------------
    event DiscountApplied(
        address indexed buyer,
        uint ticketsBought,
        uint indexed usdcAmountUsed
    );
    event UpdatedLottery(
        address indexed prevLottery,
        address indexed newLottery
    );
    event UpdatedDiscountAmount(
        uint indexed prevDiscound,
        uint indexed newDiscountAmount
    );
    //-------------------------------------------------------------------------
    //    Modifiers
    //-------------------------------------------------------------------------
    modifier isValidLottery(address _lottery) {
        if (_lottery == address(0))
            revert DiscountBooth__InvalidLotteryAddress();
        try ILottery(_lottery).ticketPrice() returns (uint _price) {
            if (_price < 0.5 ether)
                revert DiscountBooth__InvalidLotteryAddress();
            _;
        } catch {
            revert DiscountBooth__InvalidLotteryAddress();
        }
    }

    modifier isValidDiscountAmount(uint _amount, bool _constructor) {
        if (_amount > DISCOUNT_BASE || (_amount < 100 && _constructor))
            revert DiscountBooth__InvalidDiscountAmount();
        _;
    }

    //-------------------------------------------------------------------------
    //    CONSTRUCTOR
    //-------------------------------------------------------------------------
    constructor(
        address _lottery,
        address _usdc,
        uint _discount
    ) isValidLottery(_lottery) isValidDiscountAmount(_discount, true) {
        if (_usdc == address(0)) revert DiscountBooth__InvalidUSDCAddress();

        lottery = ILottery(_lottery);
        USDC = IERC20(_usdc);
        USDC.approve(_lottery, type(uint).max); // approve ALL THE USDC TO THE LOTTERY
        discountAmount = _discount;
    }

    //-------------------------------------------------------------------------
    //    External Functions
    //-------------------------------------------------------------------------

    function buyTicketsAtDiscount(
        uint ticketsToBuy,
        address _referral
    ) external nonReentrant {
        uint ticketPrice = lottery.ticketPrice();
        uint totalCost = ticketPrice * ticketsToBuy;
        uint discount = (totalCost * discountAmount) / DISCOUNT_BASE;
        // Make sure we have enough funds to cover the discount;
        if (USDC.balanceOf(address(this)) < discount)
            revert DiscountBooth__InsufficientUSDCBalance();
        // Update Global vars
        totalTicketsBought += ticketsToBuy;
        totalDiscountsGiven += discount;

        uint costWithDiscount = totalCost - discount;
        USDC.transferFrom(msg.sender, address(this), costWithDiscount);
        emit DiscountApplied(msg.sender, ticketsToBuy, costWithDiscount);
        lottery.buyTicketsForUser(ticketsToBuy, _referral, msg.sender, false);
    }

    /// @notice Update the Lottery address in case of a redeploy
    /// @param _lottery The address of the new lottery
    function updateLottery(
        address _lottery
    ) external onlyOwner isValidLottery(_lottery) {
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
    function updateDiscountAmount(
        uint _newDiscount
    ) external onlyOwner isValidDiscountAmount(_newDiscount, false) {
        if (_newDiscount > DISCOUNT_BASE)
            revert DiscountBooth__InvalidDiscount();
        emit UpdatedDiscountAmount(discountAmount, _newDiscount);
        discountAmount = _newDiscount;
    }

    /**
     * @notice Increases the approval of the lottery to spend USDC
     */
    function increaseLotteryApproval() external {
        USDC.approve(address(lottery), type(uint).max);
    }

    function availableTicketsAtDiscount() external view returns (uint) {
        uint currentBalance = USDC.balanceOf(address(this));

        return
            (currentBalance * DISCOUNT_BASE) /
            // We use 1 ether because it's the base decimals for USDC on BNB
            // ticket Price is 1 ether so we can discard it from the equation since it would only be extra calculations
            (discountAmount * 1 ether);
    }
}
