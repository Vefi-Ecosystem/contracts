pragma solidity ^0.8.0;

interface ISparkfiAdapter {
  function name() external view returns (string memory);

  function query(
    address,
    address,
    uint256
  ) external view returns (uint256);

  function swap(
    address,
    address,
    address,
    uint256,
    uint256
  ) external;
}
