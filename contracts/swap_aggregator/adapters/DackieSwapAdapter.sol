pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IDackieFactory.sol";
import "../interfaces/IDackiePair.sol";
import "../SparkfiAdapter.sol";
import "../../helpers/TransferHelper.sol";

contract DackieSwapAdapter is SparkfiAdapter {
  using SafeMath for uint256;

  uint256 internal constant FEE_DENOMINATOR = 1e3;
  uint256 public immutable feeCompliment;
  address public immutable factory;

  constructor(
    string memory _name,
    address _factory,
    uint256 fee
  ) SparkfiAdapter(_name) {
    factory = _factory;
    feeCompliment = FEE_DENOMINATOR - fee;
  }

  function _getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal view returns (uint256) {
    uint256 amountInWithFee = amountIn.mul(feeCompliment);
    uint256 numerator = amountInWithFee.mul(reserveOut);
    uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
    return numerator.div(denominator);
  }

  function _query(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) internal view override returns (uint256) {
    if (tokenIn == tokenOut || amountIn == 0) return 0;

    address pair = IDackieFactory(factory).getPair(tokenIn, tokenOut);

    if (pair == address(0)) return 0;

    (uint256 r0, uint256 r1, ) = IDackiePair(pair).getReserves();
    (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut ? (r0, r1) : (r1, r0);
    return reserveIn > 0 && reserveOut > 0 ? _getAmountOut(amountIn, reserveIn, reserveOut) : 0;
  }

  function _swap(
    address tokenIn,
    address tokenOut,
    address to,
    uint256 amountIn,
    uint256 amountOut
  ) internal override {
    address pair = IDackieFactory(factory).getPair(tokenIn, tokenOut);
    (uint256 amount0Out, uint256 amount1Out) = tokenIn < tokenOut ? (uint256(0), amountOut) : (amountOut, uint256(0));
    TransferHelpers._safeTransferERC20(tokenIn, pair, amountIn);
    IDackiePair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
  }
}
