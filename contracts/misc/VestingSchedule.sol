pragma solidity ^0.8.0;

struct VestingSchedule {
  uint8 percentage;
  uint256 startTime;
  uint256 endTime;
  uint256 withdrawalIntervals;
}
