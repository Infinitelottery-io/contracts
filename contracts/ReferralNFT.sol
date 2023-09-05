//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error IFL_ReferralNFT__InvalidAmount();
error IFL_ReferralNFT__CouldNotTransferUSDC();

/**
 * @title NFT used for Referral
 * @notice This contract is used to mint NFTs for referrals
 */

contract IFL_ReferralNFT is ERC1155, Ownable {
    // 30 - 40$ price
    // no limit on minting
    IERC20 public USDC;
    address public teamWallet;
    uint public price;

    constructor(
        string memory _uri,
        address _team,
        address _usdc
    ) ERC1155(_uri) {
        teamWallet = _team;
        USDC = IERC20(_usdc);
    }

    function mint(address forAddress, uint amount) external {
        if (amount == 0) revert IFL_ReferralNFT__InvalidAmount();
        if (!USDC.transferFrom(msg.sender, teamWallet, amount * price))
            revert IFL_ReferralNFT__CouldNotTransferUSDC();
        _mint(forAddress, 1, amount, "");
    }

    function setPrice(uint _price) external onlyOwner {
        price = _price;
    }
}
