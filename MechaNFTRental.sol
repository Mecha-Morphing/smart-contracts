// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MechaNFT.sol";
import "./MechaNFTRentalStorage.sol";

contract MechaNFTRental is Ownable {

    using SafeMath for uint256;

    event NFTDeposite(uint256 indexed tokenId, address indexed owner, uint256 indexed duration);
    event NFTWithdraw(uint256 indexed tokenId, address indexed to);
    event NFTRentStart(uint256 indexed tokenId, address indexed to);
    event NFTRentEnd(uint256 indexed tokenId, address indexed to);

    MechaNFTRentalStorage private _storageContract;
    MechaNFT private _nftContract;

    constructor(address storageContract, address nftContract) {
        require(storageContract != address(0));
        require(nftContract != address(0));

        _storageContract = MechaNFTRentalStorage(storageContract);
        _nftContract = MechaNFT(nftContract);
    }

    function depositeNFT(
        uint256 tokenId,
        uint256 duration,
        uint256 creditPoint,
        uint256 minRent,
        uint8 bonusPercent
    ) public {
        require(_msgSender() != address(0));
        require(_storageContract.ownerOf(tokenId) == address(0), "Token already transfered into NFT rental");

        _nftContract.safeTransferFrom(_msgSender(), address(_storageContract), tokenId);
        _storageContract.add(tokenId, _msgSender(), duration, creditPoint, minRent, bonusPercent);

        emit NFTDeposite(tokenId, _msgSender(), duration);
    }

    function withdrawNFT(
        address receiver,
        uint256 tokenId
    ) public {
        require(_msgSender() != address(0));

        require(_storageContract.ownerOf(tokenId) == _msgSender(), "The owner of NFT is not msg.sender");

        _storageContract.withdraw(tokenId, receiver);

        emit NFTWithdraw(tokenId, receiver);
    }

    function rentNFT(uint256 tokenId) public {
        require(_msgSender() != address(0));

        _storageContract.rent(tokenId, _msgSender());
    }

    function unrentNFT(uint256 tokenId) public {
        require(_msgSender() != address(0));

        _storageContract.unrent(tokenId, _msgSender());
    }
}
