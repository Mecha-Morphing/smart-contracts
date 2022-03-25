// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MechaExToken
 * @dev stand ERC20 Token, where all tokens are pre-assigned to the owner.
 * Note they can later distribute these tokens as they wish using `transfer` or other
 * `ERC20` functions, or other contracts.
 */
contract MechaExToken is ERC20 {

    /**
     * @dev initial supply of tokens
     */
    uint256 private INITIAL_SUPPLY = 10 ** 8;

    /**
     * @dev Constructor that gives _msgSender() all of existing tokens.
     */
    constructor() ERC20("MechaExToken", "MAPE") {
        _mint(_msgSender(), INITIAL_SUPPLY * (10 ** uint256(decimals())));
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

}
