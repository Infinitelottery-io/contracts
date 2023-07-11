// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDividendNFT {
    /**
     * Function callable by anyone, it transfers the USDC to the dividend pool
     * @param amount The amount of USDC to distribute to the dividend pool
     */
    function distributeDividends(uint256 amount) external;
}
