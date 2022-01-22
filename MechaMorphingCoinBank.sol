// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MechaMorphingCoin.sol";

contract MechaMorphingCoinBank is Ownable, Pausable, EIP712 {

    using SafeMath for uint256;
    using SafeERC20 for MechaMorphingCoin;
    using Counters for Counters.Counter;

    event MMCDeposite(address indexed player, uint256 indexed amount);
    event MMCWithdraw(address indexed player, uint256 indexed amount, uint256 withdrawId);

    MechaMorphingCoin private _mmcContract;

    uint256 private _minDepositedAmount;
    uint256 private _maxDepositedAmount;
    uint256 private _minWithdrawedAmount;
    uint256 private _maxWithdrawedAmount;

    mapping(address => Counters.Counter) private _nonces;

    bytes32 private immutable _WITHDRAW_TYPEHASH = keccak256("Withdraw(address sender,uint256 nonce,uint256 amount,uint256 withdrawId)");

    constructor(
        address mmcContractAddress,
        uint256 minDepositedAmount_,
        uint256 maxDepositedAmount_,
        uint256 minWithdrawedAmount_,
        uint256 maxWithdrawedAmount_
    ) EIP712("MechaMorphingCoinBank", "1") {
        require(mmcContractAddress != address(0));
        require(minDepositedAmount_ > 0);
        require(maxDepositedAmount_ > 0);
        require(minWithdrawedAmount_ > 0);
        require(maxWithdrawedAmount_ > 0);

        _minDepositedAmount = minDepositedAmount_;
        _maxDepositedAmount = maxDepositedAmount_;
        _minWithdrawedAmount = minWithdrawedAmount_;
        _maxWithdrawedAmount = maxWithdrawedAmount_;
        _mmcContract = MechaMorphingCoin(mmcContractAddress);
    }

    function deposite(uint256 amount) public whenNotPaused {
        require(amount >= _minDepositedAmount, "amount is too small");
        require(amount <= _maxDepositedAmount, "amount is too big");

        require(_mmcContract.allowance(_msgSender(), address(this)) > amount, "allowance is not enough");

        _mmcContract.safeTransferFrom(_msgSender(), address(this), amount);

        emit MMCDeposite(msg.sender, amount);
    }

    function _withdraw(uint256 amount, uint256 withdrawId) internal whenNotPaused {
        require(amount >= _minWithdrawedAmount, "amount is too small");
        require(amount <= _maxWithdrawedAmount, "amount is too big");

        require(_msgSender() != address(0));
        require(_mmcContract.balanceOf(address(this)) > amount, "balance of bank is not enough");

        _mmcContract.safeTransfer(_msgSender(), amount);

        emit MMCWithdraw(_msgSender(), amount, withdrawId);
    }

    function withdrawWithSignature(
        uint256 amount,
        uint256 withdrawId,
        bytes memory signature
    ) public whenNotPaused {
        address sender = msg.sender;
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
                _WITHDRAW_TYPEHASH,
                sender,
                _useNonce(sender),
                amount,
                withdrawId
            )));

        address signer = ECDSA.recover(digest, signature);
        address owner = owner();
        require(owner != address(0) && signer == owner, "withdraw: invalid signature");

        _withdraw(amount, withdrawId);
    }

    function claim(uint256 amount) public onlyOwner {
        require(_mmcContract.balanceOf(address(this)) > amount, "balance of bank is not enough");
        _mmcContract.safeTransfer(_msgSender(), amount);
    }

    function mmcContract() public view returns (address) {
        return address(_mmcContract);
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

    function modifyMinWithdrawedAmount(uint256 minWithdrawedAmount_) public onlyOwner {
        require(minWithdrawedAmount_ > 0);
        _minWithdrawedAmount = minWithdrawedAmount_;
    }

    function minWithdrawedAmount() public view returns (uint256) {
        return _minWithdrawedAmount;
    }

    function modifyMaxWithdrawedAmount(uint256 maxDepositedAmount_) public onlyOwner {
        require(maxDepositedAmount_ > 0);
        _maxDepositedAmount = maxDepositedAmount_;
    }

    function maxWithdrawedAmount() public view returns (uint256) {
        return _maxDepositedAmount;
    }

    function modifyMinDepositedAmount(uint256 minDepositedAmount_) public onlyOwner {
        require(minDepositedAmount_ > 0);
        _minDepositedAmount = minDepositedAmount_;
    }

    function minDepositedAmount() public view returns (uint256) {
        return _minDepositedAmount;
    }

    function modifyMaxDepositedAmount(uint256 maxDepositedAmount_) public onlyOwner {
        require(maxDepositedAmount_ > 0);
        _maxDepositedAmount = maxDepositedAmount_;
    }

    function maxDepositedAmount() public view returns (uint256) {
        return _maxDepositedAmount;
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
}
