pragma solidity ^0.8.0;

import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../helpers/TransferHelper.sol";

abstract contract Purchasable is Ownable, ReentrancyGuard {
  using Address for address;
  using SafeERC20 for ERC20;

  // payment token
  ERC20 public immutable paymentToken;
  // price of the sale token
  uint256 public salePrice;
  // max for payment token amount
  uint256 public maxTotalPayment;
  // optional min for payment token amount
  uint256 public minTotalPayment;

  mapping(address => uint256) public paymentReceived;

  uint32 public purchaserCount;

  event Purchase(address indexed sender, uint256 paymentAmount);
  event SetMinTotalPayment(uint256 indexed minTotalPayment);

  constructor(
    ERC20 _paymentToken,
    uint256 _salePrice,
    uint256 _maxTotalPayment
  ) {
    require(
      _salePrice == 0 || (_salePrice != 0 && address(_paymentToken).isContract() && _maxTotalPayment >= _salePrice),
      "paymentToken or maxTotalPayment should not be 0 when salePrice is not 0"
    );
    salePrice = _salePrice;
    paymentToken = _paymentToken;
    maxTotalPayment = _maxTotalPayment;
  }

  function setMinTotalPayment(uint256 _minTotalPayment) public onlyOwner {
    minTotalPayment = _minTotalPayment;

    emit SetMinTotalPayment(_minTotalPayment);
  }

  function purchase(uint256 paymentAmount) public virtual {}

  function _purchase(uint256 paymentAmount, uint256 remaining) internal virtual nonReentrant {
    require(paymentAmount >= minTotalPayment, "amount below min");

    require(paymentAmount <= remaining, "exceeds max payment");

    TransferHelpers._safeTransferFromERC20(address(paymentToken), _msgSender(), address(this), paymentAmount);

    if (paymentReceived[_msgSender()] == 0) purchaserCount += 1;

    paymentReceived[_msgSender()] += paymentAmount;

    emit Purchase(_msgSender(), paymentAmount);
  }
}
