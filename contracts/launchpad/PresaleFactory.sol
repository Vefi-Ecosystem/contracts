pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Presale.sol";
import "./AllocationSale.sol";
import "../helpers/TransferHelper.sol";
import "../interfaces/IAllocator.sol";

contract PresaleFactory is Ownable, AccessControl {
  enum PresaleType {
    REGULAR,
    ALLOCATION
  }

  event PresaleCreated(
    address indexed presaleId,
    string metadataURI,
    address funder,
    uint256 salePrice,
    address indexed paymentToken,
    address indexed saleToken,
    uint256 startTime,
    uint256 endTime,
    uint256 minTotalPayment,
    uint256 maxTotalPayment,
    uint24 withdrawDelay,
    PresaleType presaleType
  );

  uint16 public salePercentageForEcosystem;
  address public feeCollector;
  IAllocator public allocator;

  bytes32 public ADMIN_ROLE = keccak256(abi.encodePacked("ADMIN_ROLE"));

  modifier onlyOwnerOrAdmin() {
    require(hasRole(ADMIN_ROLE, _msgSender()) || _msgSender() == owner());
    _;
  }

  constructor(
    uint16 _salePercentageForEcosystem,
    address _feeCollector,
    IAllocator _allocator
  ) {
    salePercentageForEcosystem = _salePercentageForEcosystem;
    feeCollector = _feeCollector;
    allocator = _allocator;
    _grantRole(ADMIN_ROLE, _msgSender());
  }

  function deploySale(
    string memory metadataURI,
    address newOwner,
    address casher,
    address funder,
    uint256 salePrice,
    address paymentToken,
    address saleToken,
    uint256 startTime,
    uint16 daysToLast,
    uint256 minTotalPayment,
    uint256 maxTotalPayment,
    uint256[] calldata claimTimes,
    uint8[] calldata pct,
    uint24 withdrawDelay,
    PresaleType presaleType
  ) external onlyOwnerOrAdmin returns (address presaleId) {
    uint256 endTime = startTime + (uint256(daysToLast) * 1 days);
    bytes memory creationCode = presaleType == PresaleType.REGULAR ? type(Presale).creationCode : type(AllocationSale).creationCode;
    bytes memory constructorArgs = presaleType == PresaleType.REGULAR
      ? abi.encode(
        metadataURI,
        funder,
        salePrice,
        paymentToken,
        saleToken,
        startTime,
        endTime,
        maxTotalPayment,
        feeCollector,
        salePercentageForEcosystem,
        owner()
      )
      : abi.encode(
        metadataURI,
        funder,
        salePrice,
        paymentToken,
        saleToken,
        startTime,
        endTime,
        maxTotalPayment,
        feeCollector,
        salePercentageForEcosystem,
        owner(),
        address(allocator)
      );

    bytes memory byteCode = abi.encodePacked(creationCode, constructorArgs);
    bytes32 salt = keccak256(abi.encodePacked(_msgSender(), funder, block.timestamp));

    assembly ("memory-safe") {
      presaleId := create2(0, add(byteCode, 32), mload(byteCode), salt)
      if iszero(extcodesize(presaleId)) {
        revert(0, "could not deploy sale contract")
      }
    }

    emit PresaleCreated(
      presaleId,
      metadataURI,
      funder,
      salePrice,
      paymentToken,
      saleToken,
      startTime,
      endTime,
      minTotalPayment,
      maxTotalPayment,
      withdrawDelay,
      presaleType
    );

    Presale pSale = Presale(presaleId);

    pSale.setCasher(casher);
    pSale.setMinTotalPayment(minTotalPayment);
    pSale.setWithdrawDelay(withdrawDelay);

    if (claimTimes.length > 0) {
      pSale.setCliffPeriod(claimTimes, pct);
    } else {
      pSale.setLinearVestingEndTime(pSale.withdrawTime() + 1);
    }

    pSale.transferOwnership(newOwner);
  }

  function withdrawToken(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function withdrawEther(address to) external onlyOwner {
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function setEcosystemPercentage(uint16 ecosystemPercentage) external onlyOwner {
    salePercentageForEcosystem = ecosystemPercentage;
  }

  function setFeeCollector(address _feeCollector) external onlyOwner {
    feeCollector = _feeCollector;
  }

  function grantAdminRole(address account) external onlyOwner {
    require(!hasRole(ADMIN_ROLE, account), "already admin");
    _grantRole(ADMIN_ROLE, account);
  }

  function revokeAdminRole(address account) external onlyOwner {
    require(hasRole(ADMIN_ROLE, account), "account is not an admin");
    _revokeRole(ADMIN_ROLE, account);
  }

  receive() external payable {}
}
