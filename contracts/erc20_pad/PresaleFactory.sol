pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Presale.sol";
import "../helpers/TransferHelper.sol";

contract PresaleFactory is Ownable, AccessControl {
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
    uint24 withdrawDelay
  );

  uint16 public salePercentageForEcosystem;
  address public feeCollector;

  constructor(uint16 _salePercentageForEcosystem, address _feeCollector) {
    salePercentageForEcosystem = _salePercentageForEcosystem;
    feeCollector = _feeCollector;
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
    uint24 withdrawDelay
  ) external onlyOwner returns (address presaleId) {
    uint256 endTime = startTime + (uint256(daysToLast) * 1 days);
    bytes memory byteCode = abi.encodePacked(
      type(Presale).creationCode,
      abi.encode(
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
    );
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
      withdrawDelay
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

  receive() external payable {}
}