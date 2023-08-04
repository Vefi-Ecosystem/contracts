pragma solidity ^0.8.0;

interface IAllocator {
  event Stake(address account, uint256 amount, uint256 timestamp);
  event Unstake(address account, uint256 amount);
  event TaxPercentageChanged(uint8 newTaxPercentage);
  event TierAdded(string name, uint256 num);

  function token() external view returns (address);

  function apr() external view returns (uint24);

  function userWeight(address) external view returns (uint256);

  function totalStaked() external view returns (uint256);

  function stake(uint256) external;

  function unstake() external;
}
