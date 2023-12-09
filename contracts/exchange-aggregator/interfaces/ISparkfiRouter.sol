pragma solidity ^0.8.0;

struct Query {
  address adapter;
  address tokenIn;
  address tokenOut;
  uint256 amountOut;
}

struct Offer {
  bytes amounts;
  bytes adapters;
  bytes path;
  uint256 gasEstimate;
}
struct FormattedOffer {
  uint256[] amounts;
  address[] adapters;
  address[] path;
  uint256 gasEstimate;
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

  function queryNoSplit(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint8[] calldata _options
  ) external view returns (Query memory);

  function findBestPathWithGas(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint256 _maxSteps,
    uint256 _gasPrice
  ) external view returns (FormattedOffer memory);

  function findBestPath(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint256 _maxSteps
  ) external view returns (FormattedOffer memory);
}
