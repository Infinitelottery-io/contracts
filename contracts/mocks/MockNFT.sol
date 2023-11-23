// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../interfaces/IDividendNFT.sol";

contract MockNft is IDividendNFT, ERC721 {
    IERC20 public usdc;
    uint public totalDividends;

    constructor(address _usdc) ERC721("MockNft", "MockNft") {
        usdc = IERC20(_usdc);
    }

    function distributeDividends(uint amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        totalDividends += amount;
    }
}
