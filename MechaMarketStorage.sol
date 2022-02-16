// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./MechaNFT.sol";

contract MechaMarketStorage is AccessControl, ERC721Holder, Ownable {

    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    // define game item struct
    struct GameItem {
        uint256 tokenId;
        address currentOwner;
        address previousOwner;
        uint256 price;
        bool forSale;
        bool sold;
    }

    // map token id to gameItem
    mapping(uint256 => GameItem) private _allGameItems;

    MechaNFT private _nftContract;

    constructor(address nftContract) {
        require(nftContract != address(0));
        _nftContract = MechaNFT(nftContract);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev Grants `role` to `account`.
     */
    function setupMarketRole(address account) public {
        require(account != address(0));
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role for market");

        super._setupRole(MARKET_ROLE, account);
    }

    function revokeMarketRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role");

        super.revokeRole(MARKET_ROLE, account);
    }

    function hasMarketRole(address account) public view returns (bool) {
        return super.hasRole(MARKET_ROLE, account);
    }

    function withdraw(uint256 tokenId, address to) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        _nftContract.transferFrom(address(this), to, tokenId);

        delete _allGameItems[tokenId];
    }

    function transferOwnerlessNFT(uint256 tokenId, address to) public onlyOwner {

        // 只有无主的nft才可以转走
        if (_allGameItems[tokenId].currentOwner == address(0)) {
            _nftContract.transferFrom(address(this), to, tokenId);
        }
    }

    function addGameItem(uint256 tokenId, address from, uint256 price) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        GameItem memory newGameItem = GameItem (
            tokenId,
            from,
            address(0),
            price,
            true,
            false
        );

        _allGameItems[tokenId] = newGameItem;
    }

    function sold(uint256 tokenId, address previousOwner, address currentOwner) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

//        GameItem memory gameItem = _allGameItems[tokenId];
//        gameItem.previousOwner = previousOwner;
//        gameItem.currentOwner = currentOwner;
//        gameItem.forSale = false;
//        gameItem.sold = true;
//
//        _allGameItems[tokenId] = gameItem;

        _nftContract.transferFrom(address(this), currentOwner, tokenId);
        delete _allGameItems[tokenId];
    }

    function changeOwner(uint256 tokenId, address previousOwner, address currentOwner) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        GameItem memory gameItem = _allGameItems[tokenId];
        gameItem.previousOwner = previousOwner;
        gameItem.currentOwner = currentOwner;

        _allGameItems[tokenId] = gameItem;
    }

    function currentOwnerOf(uint256 tokenId) public view returns (address) {
        return _allGameItems[tokenId].currentOwner;
    }

    function changeSoldStatus(uint256 tokenId, bool soldStatus) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        GameItem memory gameItem = _allGameItems[tokenId];
        gameItem.sold = soldStatus;

        _allGameItems[tokenId] = gameItem;
    }

    function soldStatusOf(uint256 tokenId) public view returns (bool) {
        return _allGameItems[tokenId].sold;
    }

    function changeSaleStatus(uint256 tokenId, bool saleStatus) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        GameItem memory gameItem = _allGameItems[tokenId];
        gameItem.forSale = saleStatus;

        _allGameItems[tokenId] = gameItem;
    }

    function saleStatusOf(uint tokenId) public view returns (bool) {
        return _allGameItems[tokenId].forSale;
    }

    function changePrice(uint256 tokenId, uint256 newPrice) public {
        require(hasRole(MARKET_ROLE, msg.sender), "Caller is not a market role");

        GameItem memory gameItem = _allGameItems[tokenId];
        gameItem.price = newPrice;

        _allGameItems[tokenId] = gameItem;
    }

    function priceOf(uint256 tokenId) public view returns (uint256) {
        GameItem memory gameItem = _allGameItems[tokenId];
        return gameItem.price;
    }

}
