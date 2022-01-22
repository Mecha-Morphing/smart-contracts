// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MechaNFT.sol";

contract MechaNFTForAdminMinter is Ownable {

    MechaNFT private _mechaNFT;

    event NFTCreateByAdmin(
        uint256 indexed tokenId,
        address indexed to
    );

    constructor(address nftContractAddress) {
        require(nftContractAddress != address(0));

        _mechaNFT = MechaNFT(nftContractAddress);
    }

    function mintMysteryBox(address to) public onlyOwner returns (uint256) {
        require(to != address(0));

        uint256 tokenId = _mechaNFT.mint(to);

        emit NFTCreateByAdmin(tokenId, to);
        return tokenId;
    }
}
