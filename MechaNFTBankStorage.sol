// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract MechaNFTBankStorage is AccessControl {

    event BankNFTDeposite(
        uint256 indexed tokenId,
        address indexed depositor,
        uint256 price,
        uint256 indexed depositedTime
    );
    event BankNFTWithdraw(uint256 indexed tokenId);

    struct DepositeItem {
        address depositor;
        uint256 price;
        address mmcAccount;
        uint256 depositedTime;
    }

    mapping(uint256 => DepositeItem) private _allDepositeItems;

    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setupBankRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role");

        super._setupRole(BANK_ROLE, account);
    }

    function revokeBankRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not a admin role");

        super.revokeRole(BANK_ROLE, account);
    }

    function hasBankRole(address account) public view returns (bool) {
        return super.hasRole(BANK_ROLE, account);
    }

    function add(address depositor_, uint256 tokenId_, uint256 price_, address mmcAccount_) public {
        require(hasRole(BANK_ROLE, msg.sender), "Caller is not a bank role");

        DepositeItem memory item = _allDepositeItems[tokenId_];
        require(item.depositor == address(0), "MechaNFTBankStorage: The token already exists");

        uint256 depositedTime_ = block.timestamp;
        _allDepositeItems[tokenId_]  = DepositeItem(depositor_, price_, mmcAccount_, depositedTime_);

        emit BankNFTDeposite(tokenId_, depositor_, price_, depositedTime_);
    }

    function remove(uint256 tokenId_) public {
        require(hasRole(BANK_ROLE, msg.sender), "Caller is not a bank role");

        DepositeItem memory item = _allDepositeItems[tokenId_];
        require(item.depositor == address(0), "NFT dose not exist");

        item.depositor = address(0);
        item.mmcAccount = address(0);
        item.price = 0;
        item.depositedTime = 0;

        _allDepositeItems[tokenId_] = item;

        emit BankNFTWithdraw(tokenId_);
    }

    function info(uint256 tokenId) public view returns (address, uint256, address, uint256) {
        DepositeItem memory item = _allDepositeItems[tokenId];
        return (item.depositor, item.price, item.mmcAccount, item.depositedTime);
    }

    function depositor(uint256 tokenId) public view returns (address) {
        return _allDepositeItems[tokenId].depositor;
    }

    function depositedTime(uint256 tokenId) public view returns (uint256) {
        return _allDepositeItems[tokenId].depositedTime;
    }

    function price(uint256 tokenId) public view returns (uint256) {
        return _allDepositeItems[tokenId].price;
    }

    function mmcAccount(uint256 tokenId) public view returns (address) {
        return _allDepositeItems[tokenId].mmcAccount;
    }
}
