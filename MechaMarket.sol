// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./MechaNFT.sol";
import "./MechaMarketStorage.sol";

contract MechaMarket is EIP712("MechaMarket", "1"), Ownable {

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    event NFTDeposite(uint256 indexed tokenId, address indexed seller, uint256 indexed price);
    event NFTWithdraw(uint256 indexed tokenId, address indexed to);
    event NFTPurchase(uint256 indexed tokenId, address indexed buyer);
    event NFTPriceChanged(uint256 indexed tokenId, address indexed seller, uint256 indexed newPrice);
    event NFTUpShelf(uint256 indexed tokenId, address indexed seller, uint256 indexed price);
    event NFTDownShelf(uint256 indexed tokenId, address indexed seller);

    bytes32 private constant STRUCT_WithdrawNFT_SELECTOR = keccak256("WithdrawNFT(address sender,uint256 nonce,address receiver,uint256 tokenId)");
    mapping(address => Counters.Counter) private _nonces;

    MechaNFT private _nftContract;
    MechaMarketStorage private _storageContract;

    address private _commissionBeneficiary;
    uint256 private _commissionRate;

    constructor(
        address nftContract,
        address storageContract,
        address commissionBeneficiary_,
        uint256 commissionRate_
    ) {
        require(nftContract != address(0));
        require(storageContract != address(0));
        require(commissionBeneficiary_ != address(0));
        require(commissionRate_ > 0 && commissionRate_ < 100);

        _nftContract = MechaNFT(nftContract);
        _storageContract = MechaMarketStorage(storageContract);

        _commissionBeneficiary = commissionBeneficiary_;
        _commissionRate = commissionRate_;
    }

    function depositeNFT(
        uint256 tokenId,
        uint256 price
    )
    public
    {
        require(msg.sender != address(0), "bad msg sender");
        require(_storageContract.currentOwnerOf(tokenId) == address(0), "Token already transfered into NFT market");

        _storageContract.addGameItem(tokenId, msg.sender, price);
        _nftContract.transferFrom(msg.sender, address(_storageContract), tokenId);

        emit NFTDeposite(tokenId, msg.sender, price);
    }

    /**
     * @dev buyer call function with signed data to withdraw NFT.
     * @param receiver address to receive NFT
     * @param tokenId tokenId uint256 ID of the token
     */
    function withdrawNFT(
        address receiver,
        uint256 tokenId,
        bytes calldata signature
    )
    public {
        // admin sign check
        address sender = msg.sender;
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(STRUCT_WithdrawNFT_SELECTOR, sender, _useNonce(sender), receiver, tokenId))
        );
        address signer = ECDSA.recover(digest, signature);
        address owner = owner();
        require(owner != address(0) && signer == owner, "invalid request");

        _withdrawNFT(receiver, tokenId);
    }

    /**
     * @dev buyer call function with signed data to withdraw NFT.
     * @param receiver address to receive NFT
     * @param tokenId tokenId uint256 ID of the token
     */
    function _withdrawNFT(
        address receiver,
        uint256 tokenId
    )
    internal
    {
        require(msg.sender != address(0));

        address tokenOwner = _storageContract.currentOwnerOf(tokenId);
        require(tokenOwner != address(0), "NFT dosen't exist in market");
        require(tokenOwner == msg.sender, "The owner of NFT is not msg.sender");

        _storageContract.withdraw(tokenId, receiver);

        emit NFTWithdraw(tokenId, receiver);
    }

//    /**
//     * @dev switch between set for sale and set not for sale.
//     * @param tokenId tokenId uint256 ID of the token
//     */
//    function toggleForSale(uint256 tokenId) public {
//        require(msg.sender != address(0));
//
//        address tokenOwner = _storageContract.currentOwnerOf(tokenId);
//        require(tokenOwner != address(0), "NFT dosen't exist in market");
//        require(tokenOwner == msg.sender, "The owner of NFT is not msg.sender");
//
//        // if token's forSale is false make it true and vice versa
//        bool oldSaleFlag = _storageContract.saleStatusOf(tokenId);
//        _storageContract.changeSaleStatus(tokenId, !oldSaleFlag);
//
//        if (oldSaleFlag) {
//            emit NFTDownShelf(tokenId, tokenOwner);
//        } else {
//            emit NFTUpShelf(tokenId, tokenOwner, _storageContract.priceOf(tokenId));
//        }
//    }

    function changeNFTPrice(uint256 tokenId, uint256 newPrice) public {
        require(msg.sender != address(0));

        address tokenOwner = _storageContract.currentOwnerOf(tokenId);
        require(tokenOwner != address(0), "NFT dosen't exist in market");
        require(tokenOwner == msg.sender, "The owner of NFT is not msg.sender");
        // require(_storageContract.saleStatusOf(tokenId) == false, "NFT is on sale, can not modify price");

        // update token's price with new price
        _storageContract.changePrice(tokenId, newPrice);

        emit NFTPriceChanged(tokenId, tokenOwner, newPrice);
    }

    function purchaseNFT(uint256 tokenId) public payable {
        require(msg.sender != address(0));

        address tokenOwner = _storageContract.currentOwnerOf(tokenId);
        require(tokenOwner != address(0), "NFT dosen't exist in market");
        require(tokenOwner != msg.sender, "msg.sender cannot be the owner of NFT");
        require(_storageContract.saleStatusOf(tokenId), "NFT is not on sale");

        // check price
        uint256 price = _storageContract.priceOf(tokenId);
        require(price <= msg.value, "token is less than price!");

        uint256 realPrice = price.mul(100 - _commissionRate).div(100);
        uint256 commission = price.sub(realPrice);
        payable(tokenOwner).transfer(realPrice);
        if (commission > 0) {
            payable(_commissionBeneficiary).transfer(commission);
        }

        _storageContract.sold(tokenId, tokenOwner, msg.sender);

        emit NFTPurchase(tokenId, msg.sender);
    }

    /**
     * @return return seller and price of game item by tokenId
     * @param tokenId tokenId
     */
    function sellerAndPrice(uint256 tokenId) public view returns (address, uint256) {
        return (
        _storageContract.currentOwnerOf(tokenId),
        _storageContract.priceOf(tokenId)
        );
    }

    /**
     * change commission rate of buying
     * @param newCommissionRate commission rate.
     */
    function commissionRate(uint256 newCommissionRate)
    public
    onlyOwner
    {
        require(newCommissionRate >= 0 && newCommissionRate < 100, "commission's range [0, 100)");
        _commissionRate = newCommissionRate;
    }

    /**
     * @return commission rate of buying
     */
    function commissionRate()
    public
    view
    returns (uint256)
    {
        return _commissionRate;
    }

    function nonce(address account) public view returns (uint256) {
        return _nonces[account].current();
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _useNonce(address account) internal returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[account];
        current = nonce.current();
        nonce.increment();
    }

}
