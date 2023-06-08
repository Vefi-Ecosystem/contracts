pragma solidity ^0.8.0;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "node_modules/@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Whitelistable is Ownable, AccessControl, ReentrancyGuard {
  bytes32 public whitelistRootHash;
  bytes32 public WHITELIST_SETTER_ROLE = keccak256(abi.encodePacked("WHITELIST_SETTER_ROLE"));

  event SetWhitelistSetter(address indexed whitelistSetter);
  event RemoveWhitelistSetter(address indexed whitelistSetter);
  event SetWhitelist(bytes32 indexed whitelistRootHash);

  modifier onlyWhitelistSetterOrOwner() {
    require(hasRole(WHITELIST_SETTER_ROLE, _msgSender()) || _msgSender() == owner(), "caller not whitelist setter or owner");
    _;
  }

  function setWhitelistSetter(address _whitelistSetter) public onlyOwner {
    require(!hasRole(WHITELIST_SETTER_ROLE, _whitelistSetter), "already whitelist setter");

    _grantRole(WHITELIST_SETTER_ROLE, _whitelistSetter);

    emit SetWhitelistSetter(_whitelistSetter);
  }

  function removeWhitelistSetter(address _whitelistSetter) public onlyOwner {
    require(hasRole(WHITELIST_SETTER_ROLE, _whitelistSetter), "not whitelist setter");
    _revokeRole(WHITELIST_SETTER_ROLE, _whitelistSetter);
    emit RemoveWhitelistSetter(_whitelistSetter);
  }

  function setWhitelist(bytes32 _whitelistRootHash) public onlyWhitelistSetterOrOwner {
    whitelistRootHash = _whitelistRootHash;

    emit SetWhitelist(_whitelistRootHash);
  }

  function whitelistedPurchase(uint256 paymentAmount, bytes32[] calldata merkleProof) public virtual {}

  function withdrawGiveaway(bytes32[] calldata merkleProof) public virtual nonReentrant {}
}
