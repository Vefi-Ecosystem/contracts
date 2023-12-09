pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IAerodromeFactory.sol";
import "../interfaces/IAerodromePool.sol";
import "../SparkfiAdapter.sol";
import "../../helpers/TransferHelper.sol";

contract AerodromeAdapter is SparkfiAdapter {
  using SafeMath for uint256;
  address public immutable factory;

  constructor(
    string memory _name,
    address _factory,
    uint256 _swapGasEstimate
  ) SparkfiAdapter(_name, _swapGasEstimate) {
    factory = _factory;
  }

  function _query(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) internal view override returns (uint256) {
    if (tokenIn == tokenOut || amountIn == 0) return 0;

    // Try stable first
    address pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, 1);

    if (pair == address(0)) pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, 0); // Try volatile

    if (pair == address(0)) return 0;

    return IPool(pair).getAmountOut(amountIn, tokenIn);
  }

  function _swap(
    address tokenIn,
    address tokenOut,
    address to,
    uint256 amountIn,
    uint256 amountOut
  ) internal override {
    // Try stable first
    address pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, 1);

    if (pair == address(0)) pair = IPoolFactory(factory).getPool(tokenIn, tokenOut, 0); // Try volatile

    (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut ? (uint256(0), amountOut) : (amountOut, uint256(0));
    TransferHelpers._safeTransferERC20(tokenIn, pair, amountIn);
    IPool(pair).swap(amount0Out, amount1Out, to, new bytes(0));
  }
}
