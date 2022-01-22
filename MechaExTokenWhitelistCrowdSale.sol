// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title MechaExTokenWhitelistCrowdSale
 * @dev A token granting contract that can release its token balance. Optionally paused by the owner.
 */
contract MechaExTokenWhitelistCrowdSale is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event TokensReleased(address indexed beneficiary, uint256 indexed amount);
    event TokenRevoked(address indexed beneficiary, uint256 indexed amount);
    event TokenRevokedAll(uint256 indexed amount);

    IERC20 private _erc20Token;
    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint8 private _firstReleasedPercent;
    uint256 private _startTime;
    uint256 private _lockedTime;
    uint256 private _precision;
    uint256 private _duration;

    // address => limitedCap
    mapping (address => uint256) _limited;
    mapping (address => uint256) private _released;
    mapping (address => bool) private _paused;

    /**
     * @dev Creates a granting contract that grants its balance of any ERC20 token to the
     * beneficiary. Based on some rules all of the balance will have released.
     * @param erc20ContractAddress address of the erc20 token contract
     * @param firstReleasedPercent_ the percent of released amount firstly
     * @param startTime_ the time (as Unix time) at which point granting starts
     * @param precision_ by seconds linearly to grant
     * @param periods_ the periods in which the tokens will grant
     */
    constructor (
        address erc20ContractAddress,
        uint8 firstReleasedPercent_,
        uint256 startTime_,
        uint256 lockedDuration_,
        uint256 precision_,
        uint256 periods_
    ) {
        require(erc20ContractAddress != address(0));
        require(firstReleasedPercent_ >= 0 && firstReleasedPercent_ <= 100);
        require(startTime_ > block.timestamp, "TokenGranting: final time is before current time");
        require(precision_ > 0, "TokenGranting: precision is 0");
        require(precision_ < 10 * 360 * 24 * 60 * 60, "TokenGranting: precision is not bigger than 10 years");
        require(periods_ > 0, "TokenGranting: periods is 0");

        _erc20Token = IERC20(erc20ContractAddress);
        _firstReleasedPercent = firstReleasedPercent_;
        _startTime = startTime_;
        _lockedTime = startTime_.add(lockedDuration_);
        _precision = precision_;
        _duration = precision_.mul(periods_);
    }

    function addBeneficiary(address beneficiary, uint256 limited_) public onlyOwner {
        require(limited_ >= 1);
        require(_limited[beneficiary] == 0);
        require(_released[beneficiary] == 0, "Have released, Don't modify limited");

        _limited[beneficiary] = limited_;
    }

    /**
     * @notice only beneficiary can call this function.
     */
    function release() public {
        require(_limited[_msgSender()] > 0, "The beneficiary don't exist");
        require(!_paused[_msgSender()], "The beneficiary have been revoked");

        uint256 unreleased = releasableAmount(_msgSender());
        require(unreleased > 0, "no tokens are due");

        uint256 availableBalance = _erc20Token.balanceOf(address(this));
        require(availableBalance >= unreleased, "The approved balance of contract is not enough");

        _released[msg.sender] = _released[msg.sender].add(unreleased);
        _erc20Token.safeTransfer(msg.sender, unreleased);

        emit TokensReleased(msg.sender, unreleased);
    }

    /**
     * @notice Allows the owner to pause the granting. Tokens already released
     * remain in the contract, the rest are returned to the owner.
     */
    function pause(address beneficiary) public onlyOwner {
        require(!_paused[beneficiary], "The beneficiary have been pauseed");

        _paused[beneficiary] = true;
    }

    function unpause(address beneficiary) public onlyOwner {
        require(_paused[beneficiary], "The beneficiary have been unpauseed");

        _paused[beneficiary] = false;
    }

    /**
     * @return true if the token is revoked.
     */
    function pausedFlag(address beneficiary) public view returns (bool) {
        return _paused[beneficiary];
    }

    function releasableAmount(address beneficiary) public view returns (uint256) {
        return _grantedAmount(beneficiary).sub(_released[beneficiary]);
    }

    /**
     * @dev Calculates the amount that has already granted.
     */
    function _grantedAmount(address beneficiary) private view returns (uint256) {

        uint256 limitedAmount = _limited[beneficiary];

        uint256 firstReleased = limitedAmount.mul(_firstReleasedPercent).div(100);
        uint256 linearlyReleased = limitedAmount.sub(firstReleased);

        if (block.timestamp < _startTime) { // not start
            return 0;
        } else if (block.timestamp >= _startTime
            && block.timestamp < _lockedTime) { // during locking periods
            return firstReleased;
        } else if (block.timestamp >= _lockedTime.add(_duration)) { // already close
            return firstReleased + linearlyReleased;
        } else { // in progress
            uint256 pastDuration = block.timestamp.sub(_lockedTime);
            // 分子
            uint256 numerator = pastDuration.div(_precision);
            if (pastDuration.mod(_precision) > 0) numerator = numerator.add(1);

            // 分母
            uint256 denominator = _duration.div(_precision);
            if (_duration.mod(_precision) > 0) denominator = denominator.add(1);

            return firstReleased + linearlyReleased.mul(numerator).div(denominator);
        }
    }

    /**
     * @return the amount of the token released.
     */
    function released(address beneficiary) public view returns (uint256) {
        return _released[beneficiary];
    }

    /**
     * @return the limited of the beneficiary.
     */
    function limited(address beneficiary) public view returns (uint256) {
        return _limited[beneficiary];
    }

    /**
     * @return the start time of the token granting.
     */
    function startTime() public view returns (uint256) {
        return _startTime;
    }

    /**
     * @return the locked time of the token granting.
     */
    function lockedTime() public view returns (uint256) {
        return _lockedTime;
    }

    /**
     * @return the precision of the token granting.
     */
    function precision() public view returns (uint256) {
        return _precision;
    }

    /**
     * @return the duration of the token granting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }
}

