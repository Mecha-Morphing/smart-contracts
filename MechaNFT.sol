// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MechaNFT
 * @dev stand ERC721 Token without tokenUri. The game server use tokenId to link application
 * which supply API to retireve tokenUri.
 */
contract MechaNFT is ERC721Enumerable, ERC721Pausable, Ownable, AccessControl {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC721("MechaNFT", "MNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // _setupRole(MINTER_ROLE, _msgSender());
    }

    /**
     * @dev Function to mint a new token which beneficiary is msg.sender.
     * Reverts if the given token ID already exists.
     * @return tokenId uint256 ID of the token to be minted
     */
    function mint(address to) public whenNotPaused returns (uint256) {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        _mint(to, newTokenId);

        //_setTokenURI(newTokenId, Strings.fromUint256(newTokenId));

        return newTokenId;
    }

    /**
     * @dev Grants `role` to `account`.
     */
    function setupMinterRole(address account) public {
        require(account != address(0));
        super._setupRole(MINTER_ROLE, account);
    }

    /**
     * @dev Revokes `minter role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeMinterRole(address account) public onlyRole(getRoleAdmin(DEFAULT_ADMIN_ROLE)) {
        require(account != address(0));
        super.revokeRole(MINTER_ROLE, account);
    }

    /**
     * @dev Returns `true` if `account` has been granted `minter role`.
     */
    function hasMinterRole(address account) public view returns (bool) {
        return super.hasRole(MINTER_ROLE, account);
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

    /**
     * @dev Returns whether the specified token exists.
     * @param tokenId uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return super._exists(tokenId);
    }

    /**
     * override(ERC721, ERC721Enumerable, ERC721Pausable)
     * here you're overriding _beforeTokenTransfer method of
     * three Base classes namely ERC721, ERC721Enumerable, ERC721Pausable
     * */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal
    override(ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * override(ERC721, ERC721Enumerable) -> here you're specifying only two base classes ERC721, ERC721Enumerable
     * */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
