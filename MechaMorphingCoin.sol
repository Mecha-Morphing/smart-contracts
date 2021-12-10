// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MechaMorphingCoin is ERC20 {
    constructor() ERC20("MechaMorphingCoin", "MMC") {
        _mint(msg.sender, 100000000 * 10**uint(decimals()));
    }
}
