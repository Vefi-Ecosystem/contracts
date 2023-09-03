pragma solidity ^0.8.0;

interface IAllocator {
  event Stake(address account, uint256 amount, uint256 timestamp, uint256 lockDuration);
  event Unstake(address account, uint256 amount);
  event APRChanged(uint24 apr);
  event TierAdded(string name, uint256 num);
  event TiersReset();

  function token() external view returns (address);

  function guaranteedAllocationStart() external view returns (uint256);

  function apr() external view returns (uint24);

  function userWeight(address) external view returns (uint256);

  function totalStaked() external view returns (uint256);

  function stake(uint256, uint24) external;

  function unstake() external;
}
