pragma solidity ^0.8.0;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "node_modules/@openzeppelin/contracts/utils/math/Math.sol";
import "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../helpers/TransferHelper.sol";

// Inspiration: https://github.com/ImpossibleFinance/launchpad-contracts/blob/main/contracts/IFVestable.sol
abstract contract Vestable is Ownable {
  uint256 public withdrawTime;
  mapping(address => uint256) public latestClaimTime;
  using SafeMath for uint256;

  // for linear vesting
  uint256 public linearVestingEndTime;
  event SetLinearVestingEndTime(uint256 indexed linearVestingEndTime);

  // for cliff vesting
  struct CliffVesting {
    uint256 claimTime;
    uint8 percentage;
  }

  CliffVesting[] public cliffPeriod;
  event SetCliffVestingPeriod(CliffVesting[] indexed cliffPeriod);

  constructor(uint256 _withdrawTime) {
    withdrawTime = _withdrawTime;
  }

  function setWithdrawTime(uint256 _withdrawTime) internal {
    withdrawTime = _withdrawTime;
  }

  function getCliffPeriod() external view returns (CliffVesting[] memory) {
    return cliffPeriod;
  }

  function setLinearVestingEndTime(uint256 _linearVestingEndTime) public virtual onlyOwner {
    require(_linearVestingEndTime > withdrawTime, "vesting end time has to be after withdrawal start time");
    linearVestingEndTime = _linearVestingEndTime;
    delete cliffPeriod;
    emit SetLinearVestingEndTime(_linearVestingEndTime);
  }

  function setCliffPeriod(uint256[] calldata claimTimes, uint8[] calldata pct) public virtual onlyOwner {
    require(claimTimes.length == pct.length, "dates and pct doesn't match");
    require(claimTimes.length > 0, "input is empty");
    require(claimTimes.length <= 100, "input length cannot exceed 100");

    delete cliffPeriod;

    uint256 maxDate;
    uint8 totalPct;
    require(claimTimes[0] > withdrawTime, "first claim time is before end time + withdraw delay");
    for (uint256 i = 0; i < claimTimes.length; i++) {
      require(maxDate < claimTimes[i], "dates not in ascending order");
      maxDate = claimTimes[i];
      totalPct += pct[i];
      cliffPeriod.push(CliffVesting(claimTimes[i], pct[i]));
    }
    require(totalPct == 100, "total input percentage doesn't equal to 100");

    linearVestingEndTime = 0;
    emit SetCliffVestingPeriod(cliffPeriod);
  }

  function getUnlockedToken(
    uint256 totalPurchased,
    uint256 claimable,
    address user
  ) public view virtual returns (uint256) {
    // linear vesting
    if (linearVestingEndTime > block.timestamp) {
      // current claimable = total purchased * (now - last claimed time) / (total vesting time)
      return (totalPurchased * (block.timestamp - Math.max(latestClaimTime[user], withdrawTime))) / (linearVestingEndTime - withdrawTime);
    }

    // cliff vesting
    uint256 cliffPeriodLength = cliffPeriod.length;
    if (cliffPeriodLength != 0 && cliffPeriod[cliffPeriodLength - 1].claimTime > block.timestamp) {
      uint8 claimablePct;
      for (uint8 i; i < cliffPeriodLength; i++) {
        // if the cliff timestamp has been passed, add the claimable percentage
        if (cliffPeriod[i].claimTime > block.timestamp) {
          break;
        }
        if (latestClaimTime[user] < cliffPeriod[i].claimTime) {
          claimablePct += cliffPeriod[i].percentage;
        }
      }
      if (claimablePct == 0) {
        return 0;
      }
      return (totalPurchased * claimablePct) / 100;
    }
    return claimable;
  }
}
