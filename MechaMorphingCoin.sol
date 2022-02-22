// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MechaMorphingCoin
 * @dev stand ERC20 Token, where all tokens are pre-assigned to the owner.
 * Note they can later distribute these tokens as they wish using `transfer` or other
 * `ERC20` functions, or other contracts.
 */
contract MechaMorphingCoin is ERC20, Ownable {

    /**
     * @dev initial supply of tokens
     */
    uint256 private INITIAL_SUPPLY = 10 ** 11;

    /**
     * @dev Constructor that gives _msgSender() all of existing tokens.
     */
    constructor() ERC20("MechaMorphingCoin", "MMC") {
        _mint(_msgSender(), INITIAL_SUPPLY * (10 ** uint256(decimals())));
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     *  mint more
     */
    function mint(uint256 amount) public onlyOwner {
        super._mint(_msgSender(), amount * (10 ** uint256(decimals())));
    }
}
