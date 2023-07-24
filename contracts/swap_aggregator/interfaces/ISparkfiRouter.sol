pragma solidity ^0.8.0;

struct Query {
  address adapter;
  address tokenIn;
  address tokenOut;
  uint256 amountOut;
}

struct Trade {
  uint256 amountIn;
  uint256 amountOut;
  address[] path;
  address[] adapters;
}

interface ISparkfiRouter {
  function query(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) external view returns (Query memory);

  function swap(
    Trade calldata trade,
    address to,
    uint256 fee
  ) external payable;
}
