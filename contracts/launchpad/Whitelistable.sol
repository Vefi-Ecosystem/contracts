pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Whitelistable is Ownable, AccessControl, ReentrancyGuard {
  bytes32 public whitelistRootHash;
  bytes32 public WHITELIST_SETTER_ROLE = keccak256(abi.encodePacked("WHITELIST_SETTER_ROLE"));
  uint256 public whitelistStartTime;
  uint256 public whitelistEndTime;

  event SetWhitelistSetter(address indexed whitelistSetter);
  event RemoveWhitelistSetter(address indexed whitelistSetter);
  event SetWhitelist(bytes32 indexed whitelistRootHash);
  event SetWhitelistEndTime(uint256 whitelistEndTime);
  event SetWhitelistStartTime(uint256 whitelistStartTime);

  modifier onlyAfterWhitelistStarts() {
    require(block.timestamp >= whitelistStartTime, "whitelisting hasn't begun");
    _;
  }

  modifier onlyBeforeWhitelistEnds() {
    require(block.timestamp < whitelistEndTime, "must be before whitelist ends");
    _;
  }

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

  function setWhitelist(bytes32 _whitelistRootHash) public onlyWhitelistSetterOrOwner onlyBeforeWhitelistEnds onlyAfterWhitelistStarts {
    whitelistRootHash = _whitelistRootHash;

    emit SetWhitelist(_whitelistRootHash);
  }

  function setWhitelistDuration(uint256 _whitelistStartTime, uint16 _duration) external {
    uint256 _endTime = _whitelistStartTime + (_duration * 1 days);
    whitelistStartTime = _whitelistStartTime;
    whitelistEndTime = _endTime;
    emit SetWhitelistStartTime(_whitelistStartTime);
    emit SetWhitelistEndTime(_endTime);
  }

  function whitelistedPurchase(uint256 paymentAmount, bytes32[] calldata merkleProof) public virtual {}

  function withdrawGiveaway(bytes32[] calldata merkleProof) public virtual nonReentrant {}
}
