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

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
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

interface IWinnerHub {
    /**
     *
     * @param _winner The address of the winner of the round
     * @param _referral The referrer of the winner
     * @param _winAmount Amount designated to the winner
     * @param _refAmount Amount designated to the referrer
     */
    function distributeWinnings(
        address _winner,
        address _referral,
        uint _winAmount,
        uint _refAmount
    ) external;

    /**
     * @notice This function allows the winner to claim their winnings in USDC
     */
    function claimWinner() external;

    /**
     * @notice Claim referral rewards
     * @dev Winner must have a referral NFT
     * @dev 10% of rewards are used to buy tickets for referrer
     */
    function claimReferral() external;

    /**
     * @notice Updates lottery in case of an upgrade
     * @param _lottery The address of the new lottery contract
     */
    function updateLottery(address _lottery) external;

    /**
     * @notice Updates NFT in case of an upgrade
     * @param _nft The address of the new NFT contract
     */
    function updateNFTAddress(address _nft) external;
}

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
