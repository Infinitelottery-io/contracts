//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/IDividendNFT.sol";

error IFL_DividendNFT__MaxOverflow();
error IFL_DividendNFT__InvalidRoundToEdit();

contract IFL_DividendNFT is ERC721, Ownable, IDividendNFT, ReentrancyGuard {
    struct MintRoundInfo {
        uint amountMaxToMint;
        uint amountMinted; // reference variable
        uint price; // price is in USDC -> USDC is 18 decimals on BSC
        //NOTE (if deploying on other chains, make sure to adjust accordingly)
    }
    struct DividendsInfo {
        uint offsetPoints;
        uint totalClaimed;
    }
    mapping(uint _tokenId => DividendsInfo) public dividendsInfo;
    mapping(uint _roundId => MintRoundInfo) public mintRoundInfo;

    string private _uri;

    IERC20 public USDC;
    address public multiSig;
    uint public constant MAX_SUPPLY = 1500;
    uint public totalSupply = 0;
    uint public currentRound;
    uint private accumulatedDividendsToDistributePerToken = 0;
    uint private constant MAGNIFIER = 1e18;
    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------
    event RoundSetup(uint indexed roundId, uint amountMaxToMint, uint price);
    event PriceEdit(uint indexed roundId, uint price);
    event DividendsDistributed(uint amount);

    // Constructor for ERC721 nft with max mint supply of 1500
    constructor(
        address _usdc,
        address _receiver
    ) ERC721("IFL_DividendNFT", "IFL_DividendNFT") {
        mintRoundInfo[1] = MintRoundInfo(250, 0, 350 ether);
        currentRound = 1;
        USDC = IERC20(_usdc);
        multiSig = _receiver;
    }

    function mint(address forAddress, uint amount) external nonReentrant {
        MintRoundInfo storage round = mintRoundInfo[currentRound];
        if (round.amountMinted + amount > round.amountMaxToMint) {
            revert IFL_DividendNFT__MaxOverflow();
        }
        for (uint i = 0; i < totalSupply + amount; i++) {
            uint mintingId = i + totalSupply + 1;
            _safeMint(forAddress, mintingId);
            dividendsInfo[mintingId] = DividendsInfo(
                accumulatedDividendsToDistributePerToken,
                0
            );
        }
        totalSupply += amount;
        round.amountMinted += amount;
        if (round.amountMinted == round.amountMaxToMint) {
            currentRound++;
        }
        // Owner is excluded from minting fees
        if (msg.sender == owner()) return;

        uint price = round.price * amount;
        USDC.transferFrom(msg.sender, multiSig, price);
    }

    function setupRound(
        uint round,
        uint maxToMint,
        uint price
    ) external onlyOwner {
        MintRoundInfo storage roundInfo = mintRoundInfo[round];

        if (round <= currentRound && roundInfo.amountMinted > 0) {
            revert IFL_DividendNFT__InvalidRoundToEdit();
        }
        mintRoundInfo[round] = MintRoundInfo(maxToMint, 0, price);
        emit RoundSetup(round, maxToMint, price);
    }

    function setPrice(uint round, uint price) external onlyOwner {
        if (round <= currentRound) revert IFL_DividendNFT__InvalidRoundToEdit();

        MintRoundInfo storage roundInfo = mintRoundInfo[round];
        roundInfo.price = price;
        emit PriceEdit(round, price);
    }

    function claimDividends(uint[] memory idsToClaim) external nonReentrant {
        uint totalDividends = 0;
        for (uint i = 0; i < idsToClaim.length; i++) {
            uint tokenId = idsToClaim[i];
            //check ownership of tokenId
            if (ownerOf(tokenId) != msg.sender) continue;
            // check if current accumulated dividends is greater than offset
            DividendsInfo storage dividends = dividendsInfo[tokenId];
            if (
                accumulatedDividendsToDistributePerToken >
                dividends.offsetPoints
            ) {
                uint dividendsToClaim = accumulatedDividendsToDistributePerToken -
                        dividends.offsetPoints;
                dividends
                    .offsetPoints = accumulatedDividendsToDistributePerToken;
                totalDividends += dividendsToClaim;
            }
        }
        totalDividends /= MAGNIFIER;
        // TODO 10% of dividends go to buy Tickets
        USDC.transfer(msg.sender, totalDividends);
    }

    function distributeDividends(uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);
        accumulatedDividendsToDistributePerToken +=
            (amount * MAGNIFIER) /
            totalSupply;
        emit DividendsDistributed(amount);
    }

    function setURI(string memory uri) external onlyOwner {
        _uri = uri;
    }

    function setMultiSig(address _multiSig) external onlyOwner {
        multiSig = _multiSig;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }
}
