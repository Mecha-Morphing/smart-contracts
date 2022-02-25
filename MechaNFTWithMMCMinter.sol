// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MechaNFT.sol";
import "./MechaMorphingCoin.sol";
import "./MechaExToken.sol";

contract MechaNFTWithMMCMinter is Pausable, Ownable, EIP712 {

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    event MysteryBoxNFTCreate(
        uint256 indexed tokenId,
        address indexed player,
        uint8 itemType
    );
    event MysteryBoxCombine(
        uint256 indexed reservedTokenId,
        uint256 indexed burnTokenId0,
        uint256 burnTokenId1,
        uint256 burnTokenId2,
        uint256 burnTokenId3,
        uint256 combineId
    );

    MechaNFT private _mechaNFT;
    MechaExToken private _mechaExToken;
    MechaMorphingCoin private _mechaMorphingCoin;
    address payable private _wallet;

    uint256 private _mintedWeaponPrice;
    uint256 private _mintedMechaPrice;

    uint8 private _mapePercent;
    uint8 private _mmcPercent;

    uint256 private _startedTime;

    mapping(address => Counters.Counter) private _nonces;

    bytes32 private immutable _COMBINE_MINT_TYPEHASH =
    keccak256("CombineMint(address sender,uint256 nonce,uint256 reservedTokenId,uint256 burnTokenId0,uint256 burnTokenId1,uint256 burnTokenId2,uint256 burnTokenId3,uint256 combineId)");

    bool private _weaponEnable = true;

    bool private _mechaEnable = true;

    constructor(
        address nftContractAddress,
        address mapeContractAddress,
        address mmcContractAddress,
        address payable wallet_,
        uint256 mintedWeaponPrice_,
        uint256 mintedMechaPrice_,
        uint8 mapePercent_
    ) EIP712("MechaNFTWithMMCMinter", "1") {
        require(nftContractAddress != address(0));
        require(mapeContractAddress != address(0));
        require(mmcContractAddress != address(0));
        require(wallet_ != address(0));
        require(mintedWeaponPrice_ > 0 && mintedWeaponPrice_ < (10**10) * (10**18));
        require(mintedMechaPrice_ > 0 && mintedMechaPrice_ < (10**10) * (10**18));

        require(mapePercent_ >= 0 && mapePercent_ <= 100);

        _mechaNFT = MechaNFT(nftContractAddress);
        _mechaExToken = MechaExToken(mapeContractAddress);
        _mechaMorphingCoin = MechaMorphingCoin(mmcContractAddress);
        _wallet = wallet_;

        _mintedWeaponPrice = mintedWeaponPrice_;
        _mintedMechaPrice = mintedMechaPrice_;
        _mapePercent = mapePercent_;
        _mmcPercent = 100 - mapePercent_;
    }

    modifier whenStarted() {
        require(_startedTime > 0 && _startedTime <= block.timestamp, "Contract is not started");
        _;
    }

    /**
     * @dev Called by a owner to start.
     */
    function start(uint256 startedTime_) public onlyOwner {
        require(_startedTime == 0, "Have started");
        require(startedTime_ > block.timestamp, "start time can't be earlier than now");
        _startedTime = startedTime_;
    }

    function started() public view returns (bool) {
        return _startedTime > 0 && _startedTime <= block.timestamp;
    }

    function mintMysteryBox(
        uint8 itemType
    )
    public
    whenStarted
    whenNotPaused
    returns (uint256)
    {
        require(itemType >= 0 && itemType <=1, "itemType is not supported");

        address player = msg.sender;
        require(player != address(0));

        uint256 _price = 0;
        if (itemType == 0) {//mint weapon
            require(_weaponEnable, "weapon mint is disabled");
            _price = _mintedWeaponPrice;
        } else if (itemType == 1) {// mint mecha
            require(_mechaEnable, "mecha mint is disabled");
            _price = _mintedMechaPrice;
        }

        // 1. 玩家委托给平台方的交易手续费必须足够，否则不可以抽卡
        uint256 approvedMAPE = _mechaExToken.allowance(player, address(this));
        uint256 requiredMAPE = _price.mul(_mapePercent).div(100);
        require(requiredMAPE < approvedMAPE, "approved MAPE is not enougth!");

        uint256 approvedMMC = _mechaMorphingCoin.allowance(player, address(this));
        uint256 requiredMMC = _price.mul(_mmcPercent).div(100);
        require(requiredMMC < approvedMMC, "approved MMC is not enougth!");

        // 2. 从MAPE与MMC的委托账户里扣费用
        _mechaExToken.transferFrom(player, _wallet, requiredMAPE);
        _mechaMorphingCoin.transferFrom(player, _wallet, requiredMMC);

        // 3. 创建NFT
        uint256 tokenId = _mechaNFT.mint(player);

        emit MysteryBoxNFTCreate(tokenId, player, itemType);

        return tokenId;
    }

    function combineMintWithSignature(
        uint256 reservedTokenId,
        uint256 burnTokenId0,
        uint256 burnTokenId1,
        uint256 burnTokenId2,
        uint256 burnTokenId3,
        uint256 combineId,
        bytes memory signature
    )
    public
    whenStarted
    whenNotPaused
    {
        address sender = msg.sender;
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
                _COMBINE_MINT_TYPEHASH,
                sender,
                _useNonce(sender),
                reservedTokenId,
                burnTokenId0,
                burnTokenId1,
                burnTokenId2,
                burnTokenId3,
                combineId
            )));

        address signer = ECDSA.recover(digest, signature);
        require(signer != address(0) && signer == owner(), "CombineMint: invalid signature");

        _combineMint(reservedTokenId, burnTokenId0, burnTokenId1, burnTokenId2, burnTokenId3, combineId);
    }

    function _combineMint(
        uint256 reservedTokenId,
        uint256 burnTokenId0,
        uint256 burnTokenId1,
        uint256 burnTokenId2,
        uint256 burnTokenId3,
        uint256 combineId
    )
    internal
    whenStarted
    whenNotPaused
    {
        address sender = msg.sender;
        require(reservedTokenId > 0 && _mechaNFT.ownerOf(reservedTokenId) == sender, "invalid reservedTokenId value");
        require(burnTokenId0 > 0 && _mechaNFT.ownerOf(burnTokenId0) == sender, "invalid burnTokenId0 value");
        require(burnTokenId1 == 0 || _mechaNFT.ownerOf(burnTokenId1) == sender, "invalid burnTokenId1 value");
        require(burnTokenId2 == 0 || _mechaNFT.ownerOf(burnTokenId2) == sender, "invalid burnTokenId2 value");
        require(burnTokenId3 == 0 || _mechaNFT.ownerOf(burnTokenId3) == sender, "invalid burnTokenId3 value");

        _mechaNFT.burn(burnTokenId0);

        if (burnTokenId1 > 0) {
            _mechaNFT.burn(burnTokenId1);
        }
        if (burnTokenId2 > 0) {
            _mechaNFT.burn(burnTokenId2);
        }
        if (burnTokenId3 > 0) {
            _mechaNFT.burn(burnTokenId3);
        }

        emit MysteryBoxCombine(reservedTokenId, burnTokenId0, burnTokenId1, burnTokenId2, burnTokenId3, combineId);
    }

    function modifyPercent(uint8 mapePercent_) public onlyOwner {
        require(mapePercent_ >= 0 && mapePercent_ <= 100);

        _mapePercent = mapePercent_;
        _mmcPercent = 100 - mapePercent_;
    }

    function mapePercent() public view returns(uint8) {
        return _mapePercent;
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

    function nonce(address account) public view returns (uint256) {
        return _nonces[account].current();
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _useNonce(address account) internal returns (uint256 current) {
        Counters.Counter storage _nonce = _nonces[account];
        current = _nonce.current();
        _nonce.increment();
    }

    function setWeaponEnable(bool enable) public onlyOwner {
        _weaponEnable = enable;
    }

    function setMechaEnable(bool enable) public onlyOwner {
        _mechaEnable = enable;
    }

}
