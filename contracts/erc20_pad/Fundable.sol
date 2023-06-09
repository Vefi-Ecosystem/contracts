pragma solidity >=0.4.22 <=0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../helpers/TransferHelper.sol";
import "./Taxable.sol";

abstract contract Fundable is Ownable, AccessControl, Taxable, ReentrancyGuard {
  using SafeERC20 for ERC20;
  uint64 constant SALE_PRICE_DECIMALS = 10**18;
  uint64 private constant ONE_HOUR = 3600;
  uint64 private constant ONE_YEAR = 31556926;
  uint64 private constant FIVE_YEARS = 157784630;
  uint64 private constant TEN_YEARS = 315360000;

  bytes32 public FUNDER_ROLE = keccak256(abi.encodePacked("FUNDER_ROLE"));
  bytes32 public CASHER_ROLE = keccak256(abi.encodePacked("CASHER_ROLE"));

  uint256 public immutable startTime;
  uint256 public immutable endTime;
  ERC20 private immutable paymentToken;
  ERC20 private immutable saleToken;
  uint24 public withdrawDelay;
  mapping(address => bool) public hasWithdrawn;

  uint256 public saleAmount;
  bool public hasCashed;
  uint256 public totalPaymentReceived;
  uint32 public withdrawerCount;

  address public funder;
  address public casher;

  constructor(
    ERC20 _paymentToken,
    ERC20 _saleToken,
    uint256 _startTime,
    uint256 _endTime,
    address _funder,
    address _taxCollector,
    uint16 _taxPercentage,
    address _taxSetter
  ) Taxable(_taxCollector, _taxPercentage, _taxSetter) {
    require(_saleToken != _paymentToken, "saleToken = paymentToken");
    require(address(_saleToken) != address(0), "0x0 saleToken");
    require(block.timestamp < _startTime, "start timestamp too early");
    require(_startTime - ONE_YEAR < block.timestamp, "start time has to be within 1 year");
    require(_startTime < _endTime - ONE_HOUR, "end timestamp before start should be least 1 hour");
    require(_endTime - TEN_YEARS < _startTime, "end time has to be within 10 years");

    require(_funder != address(0), "0x0 funder");
    funder = _funder;

    paymentToken = _paymentToken; // can be 0 (for giveaway)
    saleToken = _saleToken;
    startTime = _startTime;
    endTime = _endTime;
  }

  modifier onlyFunder() {
    require(_msgSender() == funder, "caller not funder");
    _;
  }

  modifier onlyBeforeSale() {
    require(block.timestamp < startTime, "sale already started");
    _;
  }

  modifier onlyAfterSale() {
    require(block.timestamp > endTime + withdrawDelay, "can't withdraw before claim is started");
    _;
  }

  modifier onlyDuringSale() {
    require(startTime <= block.timestamp, "sale has not begun");
    require(block.timestamp < endTime, "sale over");
    _;
  }

  event SetCasher(address indexed casher);
  event RemoveCasher(address indexed casher);
  event Fund(address indexed sender, uint256 amount);
  event SetWithdrawDelay(uint24 indexed withdrawDelay);
  event Cash(address indexed sender, uint256 paymentTokenBalance, uint256 saleTokenBalance);
  event EmergencyTokenRetrieve(address indexed sender, uint256 amount);
  event Withdraw(address indexed sender, uint256 amount);

  function setCasher(address _casher) public onlyOwner {
    casher = _casher;
    emit SetCasher(_casher);
  }

  function setWithdrawDelay(uint24 _withdrawDelay) public virtual onlyOwner onlyBeforeSale {
    require(_withdrawDelay < FIVE_YEARS, "withdrawDelay has to be within 5 years");
    withdrawDelay = _withdrawDelay;

    emit SetWithdrawDelay(_withdrawDelay);
  }

  function getSaleTokensSold() internal virtual returns (uint256 amount);

  function fund(uint256 amount) public onlyFunder onlyBeforeSale {
    TransferHelpers._safeTransferFromERC20(address(saleToken), _msgSender(), address(this), amount);

    saleAmount += amount;

    emit Fund(_msgSender(), amount);
  }

  function cash() external onlyOwner {
    require(endTime + withdrawDelay < block.timestamp, "cannot withdraw yet");
    require(!hasCashed, "already cashed");

    hasCashed = true;

    uint256 paymentTokenBal = paymentToken.balanceOf(address(this));
    uint256 collectorsDue = (taxPercentage * paymentTokenBal) / 100;
    TransferHelpers._safeTransferERC20(address(paymentToken), casher, paymentTokenBal - collectorsDue);

    if (collectorsDue > 0) TransferHelpers._safeTransferERC20(address(paymentToken), taxCollector, collectorsDue);

    uint256 saleTokenBal = saleToken.balanceOf(address(this));

    uint256 totalTokensSold = getSaleTokensSold();

    uint256 principal = saleAmount < saleTokenBal ? saleTokenBal : saleAmount;

    uint256 amountUnsold = principal - totalTokensSold;

    TransferHelpers._safeTransferERC20(address(saleToken), funder, amountUnsold);

    emit Cash(_msgSender(), paymentTokenBal, amountUnsold);
  }

  function emergencyTokenRetrieve(address token) public onlyOwner onlyAfterSale {
    require(token != address(saleToken));

    uint256 tokenBalance = ERC20(token).balanceOf(address(this));

    TransferHelpers._safeTransferERC20(token, _msgSender(), tokenBalance);

    emit EmergencyTokenRetrieve(_msgSender(), tokenBalance);
  }

  function withdraw() public virtual nonReentrant {}

  function _withdraw(uint256 saleTokenOwed) internal virtual {
    require(saleTokenOwed > 0, "no token to be withdrawn");

    if (!hasWithdrawn[_msgSender()]) {
      withdrawerCount += 1;
      hasWithdrawn[_msgSender()] = true;
    }

    TransferHelpers._safeTransferERC20(address(saleToken), _msgSender(), saleTokenOwed);

    emit Withdraw(_msgSender(), saleTokenOwed);
  }
}
