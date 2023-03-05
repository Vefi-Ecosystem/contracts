pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ITokenSale.sol";
import "./helpers/TransferHelper.sol";
import "./misc/SaleInfo.sol";
import "./misc/VestingSchedule.sol";

contract PresaleVestable is Ownable, ReentrancyGuard, Pausable, ITokenSale {
  using SafeMath for uint256;
  using Address for address;

  address public immutable token;
  address public immutable saleCreator;
  address public immutable proceedsTo;
  address public immutable admin;

  uint256 public tokensAvailableForSale;
  uint256 public immutable tokensPerEther;
  uint256 public immutable softcap;
  uint256 public immutable hardcap;
  uint256 public immutable saleStartTime;
  uint256 public immutable saleEndTime;
  uint256 public immutable minContribution;
  uint256 public immutable maxContribution;

  uint8 public saleCreatorPercentage;

  bool public isSaleEnded;

  string public metadataURI;

  mapping(address => uint256) public balances;
  mapping(address => uint256) public amountContributed;
  mapping(address => bool) public isBanned;
  mapping(address => uint256) public nextWithdrawalTime;
  mapping(address => uint256) public currentVestingSchedule;

  SaleType public constant saleType = SaleType.PUBLIC_VESTABLE;
  VestingSchedule[] private vestingSchedule;

  modifier ifParamsSatisfied() {
    require(block.timestamp >= saleStartTime, "token_sale_not_started_yet");
    require(!isSaleEnded, "token_sale_has_ended");
    require(!isBanned[_msgSender()], "you_are_not_allowed_to_participate_in_this_sale");
    require(address(this).balance < hardcap, "hardcap_reached");
    _;
  }

  constructor(
    PresaleInfo memory saleInfo,
    uint8 _saleCreatorPercentage,
    VestingSchedule[] memory _vestingSchedule,
    string memory _metadataURI
  ) {
    token = saleInfo.token;
    saleCreator = _msgSender();
    proceedsTo = saleInfo.proceedsTo;
    tokensAvailableForSale = saleInfo.tokensForSale;
    softcap = saleInfo.softcap;
    hardcap = saleInfo.hardcap;
    tokensPerEther = saleInfo.tokensPerEther;
    saleStartTime = saleInfo.saleStartTime;
    saleEndTime = saleInfo.saleStartTime.add(uint256(saleInfo.daysToLast) * 1 days);
    saleCreatorPercentage = _saleCreatorPercentage;
    minContribution = saleInfo.minContributionEther;
    maxContribution = saleInfo.maxContributionEther;
    admin = saleInfo.admin;
    metadataURI = _metadataURI;

    for (uint256 i = 0; i < _vestingSchedule.length; i++) vestingSchedule.push(_vestingSchedule[i]);

    _transferOwnership(saleInfo.admin);
  }

  function _releaseAndUpdateBalance(VestingSchedule memory schedule) private {
    uint256 balance = balances[_msgSender()];
    uint256 val = balance.mul(schedule.percentage) / 100;
    TransferHelpers._safeTransferERC20(token, _msgSender(), val);
    balances[_msgSender()] = balance.sub(val);
  }

  function _computeNextScheduleAndWithdrawalTime() private {
    uint256 current = currentVestingSchedule[_msgSender()];

    if (current == vestingSchedule.length.sub(1))
      nextWithdrawalTime[_msgSender()] = block.timestamp.add(vestingSchedule[current].withdrawalIntervals);
    else {
      VestingSchedule memory schedule = vestingSchedule[current];
      if (block.timestamp >= schedule.endTime) {
        currentVestingSchedule[_msgSender()] = current.add(1);
        nextWithdrawalTime[_msgSender()] = block.timestamp.add(vestingSchedule[currentVestingSchedule[_msgSender()]].withdrawalIntervals);
      } else {
        nextWithdrawalTime[_msgSender()] = block.timestamp.add(schedule.withdrawalIntervals);
      }
    }
  }

  function contribute() external payable nonReentrant whenNotPaused ifParamsSatisfied {
    require(msg.value >= minContribution && msg.value <= maxContribution, "contribution_must_be_within_min_and_max_range");
    uint256 val = tokensPerEther.mul(msg.value).div(1 ether);
    require(tokensAvailableForSale >= val, "tokens_available_for_sale_is_less");
    balances[_msgSender()] = balances[_msgSender()].add(val);
    amountContributed[_msgSender()] = amountContributed[_msgSender()].add(msg.value);
    tokensAvailableForSale = tokensAvailableForSale.sub(val);
    nextWithdrawalTime[_msgSender()] = vestingSchedule[0].startTime.add(vestingSchedule[0].withdrawalIntervals);
  }

  function withdraw() external whenNotPaused nonReentrant {
    require(isSaleEnded || block.timestamp >= saleEndTime, "sale_has_not_ended");
    require(block.timestamp >= nextWithdrawalTime[_msgSender()], "cannot_withdraw_now");
    uint256 balance = balances[_msgSender()];
    require(balance > 0, "balance_is_zero");

    if (currentVestingSchedule[_msgSender()] == vestingSchedule.length.sub(1)) {
      VestingSchedule memory schedule = vestingSchedule[currentVestingSchedule[_msgSender()]];
      if (block.timestamp >= schedule.endTime) {
        TransferHelpers._safeTransferERC20(token, _msgSender(), balance);
        delete balances[_msgSender()];
      } else {
        _releaseAndUpdateBalance(schedule);
        _computeNextScheduleAndWithdrawalTime();
      }
    } else {
      VestingSchedule memory schedule = vestingSchedule[currentVestingSchedule[_msgSender()]];
      _releaseAndUpdateBalance(schedule);
      _computeNextScheduleAndWithdrawalTime();
    }
  }

  function emergencyWithdraw() external nonReentrant {
    require(!isSaleEnded, "sale_has_already_ended");
    TransferHelpers._safeTransferEther(_msgSender(), amountContributed[_msgSender()]);
    tokensAvailableForSale = tokensAvailableForSale.add(balances[_msgSender()]);
    delete balances[_msgSender()];
    delete amountContributed[_msgSender()];
  }

  function finalizeSale() external whenNotPaused onlyOwner {
    require(!isSaleEnded, "sale_has_ended");
    uint256 saleCreatorProfit = (address(this).balance * uint256(saleCreatorPercentage)).div(100);
    TransferHelpers._safeTransferEther(proceedsTo, address(this).balance.sub(saleCreatorProfit));
    TransferHelpers._safeTransferEther(saleCreator, saleCreatorProfit);

    if (tokensAvailableForSale > 0) {
      TransferHelpers._safeTransferERC20(token, proceedsTo, tokensAvailableForSale);
    }

    isSaleEnded = true;
  }

  function retrieveERC20(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    require(_token.isContract(), "must_be_contract_address");
    TransferHelpers._safeTransferERC20(_token, _to, _amount);
  }

  function switchBanAddress(address account) external onlyOwner {
    isBanned[account] = !isBanned[account];
  }

  function getVestingSchedule() external view returns (VestingSchedule[] memory) {
    return vestingSchedule;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function isPaused() external view returns (bool) {
    return paused();
  }
}
