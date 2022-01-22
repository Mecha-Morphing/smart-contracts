// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./MechaNFT.sol";

contract MechaNFTRentalStorage is AccessControl, ERC721Holder, Ownable {

    bytes32 public constant RENTAL_ROLE = keccak256("RENTAL_ROLE");

    struct Item {
        address owner;
        address tenant;
        uint256 duration; // rent duration
        uint256 creditPoint; // min credit point required
        uint256 minRent; // min profile during rent
        uint8 bonusPercent;
        uint256 depositTime;
        uint256 rentStartTime;
        uint256 rentEndTime;
        bool rented;
    }

    mapping(uint256 => Item) private _allItems;

    MechaNFT private _nftContract;

    constructor(address nftContract) {
        require(nftContract != address(0));
        _nftContract = MechaNFT(nftContract);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setupRentalRole(address account) public {
        require(account != address(0));
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role");

        super._setupRole(RENTAL_ROLE, account);
    }

    function revokeRentalRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role");

        super.revokeRole(RENTAL_ROLE, account);
    }

    function hasRentalRole(address account) public view returns (bool) {
        return super.hasRole(RENTAL_ROLE, account);
    }

    function add(
        uint256 tokenId,
        address from,
        uint256 duration,
        uint256 creditPoint,
        uint256 minRent,
        uint8 bonusPercent
    ) public {

        require(hasRole(RENTAL_ROLE, msg.sender), "Caller is not a rental role");

        Item memory newGameItem = Item (
            from,
            address(0),
            duration,
            creditPoint,
            minRent,
            bonusPercent,
            block.timestamp,
            0,
            0,
            false
        );

        _allItems[tokenId] = newGameItem;
    }

    function withdraw(uint256 tokenId, address receiver) public {
        require(hasRole(RENTAL_ROLE, msg.sender), "Caller is not a rental role");

        Item memory item = _allItems[tokenId];
        require(item.owner != address(0), "NFT dosen't exist");
        require(item.rented == false, "NFT is renting");

        _nftContract.safeTransferFrom(address(this), receiver, tokenId);

        delete _allItems[tokenId];
    }

    function rent(uint256 tokenId, address tenant) public {
        require(hasRole(RENTAL_ROLE, msg.sender), "Caller is not a rental role");

        Item memory item = _allItems[tokenId];

        require(item.rented == false, "NFT have been rented");

        require(block.timestamp < item.depositTime + item.duration, "rent time is valid");

        item.tenant = tenant;
        item.rentStartTime = block.timestamp;
        item.rented = true;

        _allItems[tokenId] = item;
    }

    function unrent(uint256 tokenId, address tenant) public {
        require(hasRole(RENTAL_ROLE, msg.sender), "Caller is not a rental role");

        Item memory item = _allItems[tokenId];

        require(item.owner != address(0), "NFT dosen't exist");

        require(item.rented == true, "NFT have not been rented");
        require(item.tenant != tenant, "The tenant of NFT is not right");

        require(block.timestamp >= (item.depositTime + item.duration), "rent time is too short, can not unrent");

        item.rentEndTime = block.timestamp;
        item.tenant = address(0);
        item.rented = false;

        _allItems[tokenId] = item;
    }

    function ownerOf(uint tokenId) public view returns (address) {
        return _allItems[tokenId].owner;
    }

    function tenantOf(uint tokenId) public view returns (address) {
        return _allItems[tokenId].tenant;
    }

    function rentedStatusOf(uint256 tokenId) public view returns (bool) {
        return _allItems[tokenId].rented;
    }

    function minRentOf(uint256 tokenId) public view returns (uint256) {
        return _allItems[tokenId].minRent;
    }

}
