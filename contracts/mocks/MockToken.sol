// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract TestToken is ERC20PresetFixedSupply {
    constructor()
        ERC20PresetFixedSupply(
            "testUSDC",
            "tUSDC",
            1000000000 ether,
            msg.sender
        )
    {}
}
