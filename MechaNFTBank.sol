// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MechaNFT.sol";
import "./MechaNFTBankStorage.sol";
import "./MechaMorphingCoin.sol";

contract MechaNFTBank is Ownable, Pausable, IERC721Receiver {

    using SafeMath for uint256;
    using SafeERC20 for MechaMorphingCoin;

    MechaNFT private _nftContract;
    MechaNFTBankStorage private _storageContract;
    MechaMorphingCoin private _mmcContract;

    address private _mmcOwner;

    uint256 private _rate;
    uint256 private _ratePeriod;
    uint256 private _maxDuration;

    /**
     * @dev Creates a storage contract for NFT bank contract.
     * @param nftContract the NFT address for mecha
     * @param storageContract the storage address for bank
     * @param mmcContract the mmc address
     * @param mmcOwner_ the owner of mmc contract
     * @param rate_ rate of interest, the precision is 10^9
     * @param ratePeriod_ period rate in seconds, 24 * 60 * 60 is for 1 day
     * @param maxDuration_ max duration in seconds of deposite
     */
    constructor(
        address storageContract,
        address nftContract,
        address mmcContract,
        address mmcOwner_,
        uint256 rate_,
        uint256 ratePeriod_,
        uint256 maxDuration_
    ) {
        require(storageContract != address(0));
        require(nftContract != address(0));
        require(mmcContract != address(0));
        require(mmcOwner_ != address(0));
        require(rate_ > 0);
        require(ratePeriod_ > 0);
        require(maxDuration_ > 0);

        _nftContract = MechaNFT(storageContract);
        _storageContract = MechaNFTBankStorage(storageContract);
        _mmcContract = MechaMorphingCoin(mmcContract);
        _mmcOwner = mmcOwner_;
        _rate = rate_;
        _ratePeriod = ratePeriod_;
        _maxDuration = maxDuration_;
    }

    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        require(msg.sender != address(0));

        (uint128 price, address mmcAccount) = abi.decode(data, (uint128, address));

        _storageContract.add(from, tokenId, price, mmcAccount);

        return this.onERC721Received.selector;
    }

    function withdraw(uint256 tokenId) public whenNotPaused returns (uint256) {
        (address depositor, , address mmcAccount,) = _storageContract.info(tokenId);

        // 1. remove deposite
        _storageContract.remove(tokenId);

        uint256 interest_ = interest(tokenId);
        // uint256 balance = _mmcContract.balanceOf(_walletAccount);
        uint allowance = _mmcContract.allowance(_mmcOwner, address(this));
        require(allowance > interest_, "The balance of bank is too short, can not transfer interest");

        // 2. transfer MMC for interest
        _mmcContract.safeTransferFrom(_mmcOwner, mmcAccount, interest_);

        // 3. transfer NFT
        _nftContract.safeTransferFrom(address(this), depositor, tokenId);

        return interest_;
    }

    function interest(uint256 tokenId) public view returns (uint256) {
        (address depositor, uint256 price, , uint256 depositedTime) = _storageContract.info(tokenId);

        require(depositor != address(0));

        uint256 depositedSeconds = block.timestamp.sub(depositedTime);
        if (depositedSeconds > _maxDuration) {
            depositedSeconds = _maxDuration;
        }

        // depositedSeconds = 20;
        // 计算利息的周期数
        uint256 depositedPeriods = depositedSeconds.div(_ratePeriod);

        // return price.mul((_rate.add(10**9) ** depositedPeriods).div((10**9) ** depositedPeriods));
        // return price.mul((_rate.add(10**9).div(10**9)) ** depositedPeriods);
        // return price.mul((_rate.div(10**9).add(1)) ** depositedPeriods);
        return price.mul((1 + _rate.div(10**9)) ** depositedPeriods);
    }

    function testBig() public pure returns (uint256) {
        uint256 price = 100000000000;
        uint256 i = 102;
        uint256 j = 100;
        return price * ((i**20)/(j**20));
    }

    function rate() public view returns (uint256) {
        return _rate;
    }

    function ratePeriod() public view returns (uint256) {
        return _ratePeriod;
    }

    function maxDuration() public view returns (uint256) {
        return _maxDuration;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyOwner whenNotPaused {
        super._pause();
    }

    /**
     * @dev Called by a pauser to unpause, triggers regular state.
     */
    function unpause() public onlyOwner whenPaused {
        super._unpause();
    }
}
