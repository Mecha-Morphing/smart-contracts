// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MechaNFT.sol";
import "./MechaMorphingCoin.sol";

contract MechaNFTMinter is Pausable, Ownable {

    using SafeMath for uint256;

    event MysteryBoxNFTCreate(
        uint256 indexed tokenId,
        address indexed player,
        uint8 itemType
    );

    MechaNFT private _mechaNFT;
    address payable private _wallet;

    uint256 private _mintedWeaponPrice;
    uint256 private _mintedMechaPrice;

    mapping(address => uint256) private _mintedHeights;
    uint256 private _mintedInterval;
    uint256 private _durationHeightForWhitelist;

    uint256 private _startedHeight;
    uint256 private _startedTime = 0;

    mapping(address => bool) private _whitelist;

    mapping(address => uint256) private _mintedAmountForWhitelist;
    uint8 private _limitedAmountForWhitelist;

    uint256 private _mintedWeapon = 0;
    uint256 private _mintedMecha = 0;

    uint256 private _capOfWeapon;
    uint256 private _capOfMecha;

    constructor(
        address mechaNFTContractAddress,
        address payable wallet_,
        uint256 mintedWeaponPrice_,
        uint256 mintedMechaPrice_,
        uint256 mintedInterval_,
        uint256 durationHeightForWhitelist_,
        uint256 capOfWeapon_,
        uint256 capOfMecha_,
        uint8 limitedAmountForWhitelist_
    ) {
        require(mechaNFTContractAddress != address(0));
        require(wallet_ != address(0));
        require(mintedWeaponPrice_ > 0 && mintedWeaponPrice_ < (10**10) * (10**18));
        require(mintedMechaPrice_ > 0 && mintedMechaPrice_ < (10**10) * (10**18));

        require(mintedInterval_ > 0);
        // in test environment, {block.number} is too small. in prod environment, {block.number} should be bigger than 1000
        // if(block.number > 1000) {
        //     require(block.number - 1 > mintedInterval_);
        // }

        require(durationHeightForWhitelist_ > 0);
        require(capOfWeapon_ > 0);
        require(capOfMecha_ > 0);
        require(limitedAmountForWhitelist_ >= 1);

        _mechaNFT = MechaNFT(mechaNFTContractAddress);
        _wallet = wallet_;
        _mintedWeaponPrice = mintedWeaponPrice_;
        _mintedMechaPrice = mintedMechaPrice_;
        _mintedInterval = mintedInterval_;
        _durationHeightForWhitelist = durationHeightForWhitelist_;
        _capOfWeapon = capOfWeapon_;
        _capOfMecha = capOfMecha_;
        _limitedAmountForWhitelist = limitedAmountForWhitelist_;
    }

    modifier whenStarted() {
        require(_startedTime > 0 && block.timestamp >= _startedTime, "Contract is not started");
        _;
    }

    modifier whenNotStarted() {
        require(_startedTime == 0 || block.timestamp < _startedTime, "Have started");
        _;
    }

    /**
     * @dev Called by a owner to start.
     */
    function start(uint256 startedTime_) public onlyOwner whenNotStarted {
        require(startedTime_ > block.timestamp, "start time can't be earlier than now");
        _startedHeight = block.number;
        _startedTime = startedTime_;
    }

    function started() public view returns (bool) {
        return _startedTime > 0 && _startedTime <= block.timestamp;
    }

    function blockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function startedTime() public view returns (uint256) {
        return _startedTime;
    }

    function mintMysteryBox(
        uint8 itemType
    )
    external
    whenStarted
    whenNotPaused
    payable
    returns (uint256)
    {
        require(itemType >= 0 && itemType <=1, "itemType is not supported");

        if (itemType == 0) {//mint weapon
            require(msg.value >= _mintedWeaponPrice, "minted weapon price too low");
        } else if (itemType == 1) {// mint mecha
            require(msg.value >= _mintedMechaPrice, "minted mecha price too low");
        }

        if (itemType == 0) {//mint weapon
            require(_mintedWeapon < _capOfWeapon);
        } else if (itemType == 1) {// mint mecha
            require(_mintedMecha < _capOfMecha);
        }

        address player = msg.sender;
        require(player != address(0));

        uint256 tokenId = 0;

        if (_whitelist[player]
        && block.number.sub(_startedHeight) < _durationHeightForWhitelist
            && _mintedAmountForWhitelist[player] < _limitedAmountForWhitelist
        ) {// for whitelist users

            tokenId = _mechaNFT.mint(player);

            _mintedAmountForWhitelist[player] = _mintedAmountForWhitelist[player].add(1);

            _wallet.transfer(msg.value);

            emit MysteryBoxNFTCreate(tokenId, player, itemType);

        } else {// for common users or whitelist users have minted to capacity

            require(block.number.sub(_mintedHeights[player]) >= _mintedInterval, "mint NFT too frequently!");

            tokenId = _mechaNFT.mint(player);

            _mintedHeights[player] = block.number;

            _wallet.transfer(msg.value);

            emit MysteryBoxNFTCreate(tokenId, player, itemType);
        }

        if (itemType == 0) {//mint weapon
            _mintedWeapon = _mintedWeapon.add(1);
        } else if (itemType == 1) {// mint mecha
            _mintedMecha = _mintedMecha.add(1);
        }

        return tokenId;
    }

    function nextMintBlock() public view returns (uint256) {
        address player = msg.sender;
        if (_whitelist[player]
        && block.number.sub(_startedHeight) < _durationHeightForWhitelist
            && _mintedAmountForWhitelist[player] < _limitedAmountForWhitelist
        ) {
            // for whitelist users
            return block.number;
        } else {
            // for common users or whitelist users have minted to capacity
            return _mintedHeights[player] + _mintedInterval;
        }
    }

    function startedHeight() public view returns (uint256) {
        return _startedHeight;
    }

    function modifyMintedWeaponPrice(uint256 newMintedPrice) public onlyOwner {
        require(newMintedPrice > 0 && newMintedPrice < (10**10) * (10**18));

        _mintedWeaponPrice = newMintedPrice;
    }

    function mintedWeaponPrice() public view returns (uint256) {
        return _mintedWeaponPrice;
    }

    function modifyMintedMechaPrice(uint256 newMintedPrice) public onlyOwner {
        require(newMintedPrice > 0 && newMintedPrice < (10**10) * (10**18));

        _mintedMechaPrice = newMintedPrice;
    }

    function mintedMechaPrice() public view returns (uint256) {
        return _mintedMechaPrice;
    }

    function modifyDurationHeightForWhitelist(uint256 durationHeight) public onlyOwner {
        require(durationHeight > 0);

        _durationHeightForWhitelist = durationHeight;
    }

    function modifyCapOfWeapon(uint256 newCapOfWeapon) public onlyOwner {
        require(newCapOfWeapon > 0);

        _capOfWeapon = newCapOfWeapon;
    }

    function capOfWeapon() public view returns (uint256) {
        return _capOfWeapon;
    }

    function mintedWeapon() public view returns (uint256) {
        return _mintedWeapon;
    }

    function modifyMaxMechaForWhitelist(uint256 newCapOfMecha) public onlyOwner {
        require(newCapOfMecha > 0);

        _capOfMecha = newCapOfMecha;
    }

    function modifyCapOfMecha(uint256 newCapOfMecha) public onlyOwner {
        require(newCapOfMecha > 0);

        _capOfMecha = newCapOfMecha;
    }

    function capOfMecha() public view returns (uint256) {
        return _capOfMecha;
    }

    function mintedMecha() public view returns (uint256) {
        return _mintedMecha;
    }

    function modifyLimitedAmountForWhitelist(uint8 newLimitedAmount) public onlyOwner {
        require(newLimitedAmount > 0);

        _limitedAmountForWhitelist = newLimitedAmount;
    }

    function limitedAmountForWhitelist() public view returns (uint8) {
        return _limitedAmountForWhitelist;
    }

    function existOfWhitelist(address account) public view returns (bool) {
        return _whitelist[account];
    }

    function addWhitelist(address account) public onlyOwner {
        require(account != address(0));
        _whitelist[account] = true;
    }

    function addWhitelists(address[] memory accounts) public onlyOwner {
        require(accounts.length != 0, "accounts length is 0");

        for(uint i = 0; i < accounts.length; i++) {
            addWhitelist(accounts[i]);
        }
    }

    function revokeWhitelist(address account) public onlyOwner {
        require(account != address(0));

        _whitelist[account] = false;
    }

    function revokeWhitelists(address[] memory accounts) public onlyOwner {
        require(accounts.length != 0, "accounts length is 0");

        for(uint i = 0; i < accounts.length; i++) {
            revokeWhitelist(accounts[i]);
        }
    }

    function modifyMintedInterval(uint256 newMintedInterval) public onlyOwner {
        require(newMintedInterval > 0); //  && newMintedInterval < block.number - 1

        _mintedInterval = newMintedInterval;
    }

    function mintedInterval() public view returns (uint256) {
        return _mintedInterval;
    }

    function modifyWallet(address payable newWallet) public onlyOwner {
        require(newWallet != address(0));

        _wallet = newWallet;
    }

    function wallet() public view returns (address) {
        return _wallet;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyOwner whenNotPaused whenStarted {
        super._pause();
    }

    /**
     * @dev Called by a pauser to unpause, triggers regular state.
     */
    function unpause() public onlyOwner whenPaused whenStarted {
        super._unpause();
    }

}
