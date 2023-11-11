pragma solidity ^0.8.0;

import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakePair.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPancakeRouter.sol";
import "./libraries/FabulousLib.sol";
import "../interfaces/IWETH.sol";
import "../helpers/TransferHelper.sol";
import "./interfaces/IFabulousERC20.sol";

contract FabulousExchangeRouter is IPancakeRouter02 {
  using SafeMath for uint256;

  address public immutable factory;
  address public immutable WETH;

  modifier ensure(uint256 deadline) {
    require(deadline >= block.timestamp, "EXPIRED");
    _;
  }

  constructor(address _factory, address _WETH) {
    factory = _factory;
    WETH = _WETH;
  }

  receive() external payable {
    assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
  }

  // **** ADD LIQUIDITY ****
  function _addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin
  ) internal virtual returns (uint256 amountA, uint256 amountB) {
    // create the pair if it doesn't exist yet
    if (IPancakeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
      IPancakeFactory(factory).createPair(tokenA, tokenB);
    }
    (uint256 reserveA, uint256 reserveB) = FabulousLibrary.getReserves(factory, tokenA, tokenB);
    if (reserveA == 0 && reserveB == 0) {
      (amountA, amountB) = (amountADesired, amountBDesired);
    } else {
      uint256 amountBOptimal = FabulousLibrary.quote(amountADesired, reserveA, reserveB);
      if (amountBOptimal <= amountBDesired) {
        require(amountBOptimal >= amountBMin, "INSUFFICIENT_B_AMOUNT");
        (amountA, amountB) = (amountADesired, amountBOptimal);
      } else {
        uint256 amountAOptimal = FabulousLibrary.quote(amountBDesired, reserveB, reserveA);
        assert(amountAOptimal <= amountADesired);
        require(amountAOptimal >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        (amountA, amountB) = (amountAOptimal, amountBDesired);
      }
    }
  }

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
    external
    virtual
    override
    ensure(deadline)
    returns (
      uint256 amountA,
      uint256 amountB,
      uint256 liquidity
    )
  {
    (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
    address pair = FabulousLibrary.pairFor(factory, tokenA, tokenB);
    TransferHelpers._safeTransferFromERC20(tokenA, msg.sender, pair, amountA);
    TransferHelpers._safeTransferFromERC20(tokenB, msg.sender, pair, amountB);
    liquidity = IPancakePair(pair).mint(to);
  }

  function addLiquidityETH(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  )
    external
    payable
    virtual
    override
    ensure(deadline)
    returns (
      uint256 amountToken,
      uint256 amountETH,
      uint256 liquidity
    )
  {
    (amountToken, amountETH) = _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
    address pair = FabulousLibrary.pairFor(factory, token, WETH);
    TransferHelpers._safeTransferFromERC20(token, msg.sender, pair, amountToken);
    IWETH(WETH).deposit{value: amountETH}();
    assert(IERC20(WETH).transfer(pair, amountETH));
    liquidity = IPancakePair(pair).mint(to);
    // refund dust eth, if any
    if (msg.value > amountETH) TransferHelpers._safeTransferEther(msg.sender, msg.value - amountETH);
  }

  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
    address pair = FabulousLibrary.pairFor(factory, tokenA, tokenB);
    IERC20(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
    (uint256 amount0, uint256 amount1) = IPancakePair(pair).burn(to);
    (address token0, ) = FabulousLibrary.sortTokens(tokenA, tokenB);
    (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
    require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");
  }

  function removeLiquidityWithPermit(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual override returns (uint256 amountA, uint256 amountB) {
    address pair = FabulousLibrary.pairFor(factory, tokenA, tokenB);
    uint256 value = approveMax ? uint256(int256(-1)) : liquidity;
    IFabulousERC20(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
  }

  function removeLiquidityETH(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
    (amountToken, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
    TransferHelpers._safeTransferERC20(token, to, amountToken);
    IWETH(WETH).withdraw(amountETH);
    TransferHelpers._safeTransferEther(to, amountETH);
  }

  function removeLiquidityETHWithPermit(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
    address pair = FabulousLibrary.pairFor(factory, token, WETH);
    uint256 value = approveMax ? uint256(int256(-1)) : liquidity;
    IFabulousERC20(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
  }

  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline
  ) public virtual override ensure(deadline) returns (uint256 amountETH) {
    (, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
    TransferHelpers._safeTransferERC20(token, to, IERC20(token).balanceOf(address(this)));
    IWETH(WETH).withdraw(amountETH);
    TransferHelpers._safeTransferEther(to, amountETH);
  }

  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address token,
    uint256 liquidity,
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address to,
    uint256 deadline,
    bool approveMax,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual override returns (uint256 amountETH) {
    address pair = FabulousLibrary.pairFor(factory, token, WETH);
    uint256 value = approveMax ? uint256(int256(-1)) : liquidity;
    IFabulousERC20(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
  }

  // **** SWAP ****
  // requires the initial amount to have already been sent to the first pair
  function _swap(
    uint256[] memory amounts,
    address[] memory path,
    address _to
  ) internal virtual {
    for (uint256 i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0, ) = FabulousLibrary.sortTokens(input, output);
      uint256 amountOut = amounts[i + 1];
      (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
      address to = i < path.length - 2 ? FabulousLibrary.pairFor(factory, output, path[i + 2]) : _to;
      IPancakePair(FabulousLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to);
    }
  }

  function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
    for (uint256 i; i < path.length - 1; i++) {
      (address input, address output) = (path[i], path[i + 1]);
      (address token0, ) = FabulousLibrary.sortTokens(input, output);
      IPancakePair pair = IPancakePair(FabulousLibrary.pairFor(factory, input, output));
      uint256 amountInput;
      uint256 amountOutput;
      {
        // scope to avoid stack too deep errors
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
        amountOutput = FabulousLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
      }
      (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
      address to = i < path.length - 2 ? FabulousLibrary.pairFor(factory, output, path[i + 2]) : _to;
      pair.swap(amount0Out, amount1Out, to);
    }
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
    amounts = FabulousLibrary.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
    _swap(amounts, path, to);
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) {
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amountIn);
    uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    _swapSupportingFeeOnTransferTokens(path, to);
    require(IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
  }

  function swapTokensForExactTokens(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
    amounts = FabulousLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= amountInMax, "EXCESSIVE_INPUT_AMOUNT");
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
    _swap(amounts, path, to);
  }

  function swapExactETHForTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
    require(path[0] == WETH, "INVALID_PATH");
    amounts = FabulousLibrary.getAmountsOut(factory, msg.value, path);
    require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
    IWETH(WETH).deposit{value: amounts[0]}();
    assert(IERC20(WETH).transfer(FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
    _swap(amounts, path, to);
  }

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable virtual override ensure(deadline) {
    require(path[0] == WETH, "INVALID_PATH");
    uint256 amountIn = msg.value;
    IWETH(WETH).deposit{value: amountIn}();
    assert(IERC20(WETH).transfer(FabulousLibrary.pairFor(factory, path[0], path[1]), amountIn));
    uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    _swapSupportingFeeOnTransferTokens(path, to);
    require(IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
  }

  function swapTokensForExactETH(
    uint256 amountOut,
    uint256 amountInMax,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
    require(path[path.length - 1] == WETH, "INVALID_PATH");
    amounts = FabulousLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= amountInMax, "EXCESSIVE_INPUT_AMOUNT");
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
    _swap(amounts, path, address(this));
    IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    TransferHelpers._safeTransferEther(to, amounts[amounts.length - 1]);
  }

  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
    require(path[path.length - 1] == WETH, "INVALID_PATH");
    amounts = FabulousLibrary.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
    _swap(amounts, path, address(this));
    IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    TransferHelpers._safeTransferEther(to, amounts[amounts.length - 1]);
  }

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external virtual override ensure(deadline) {
    require(path[path.length - 1] == WETH, "INVALID_PATH");
    TransferHelpers._safeTransferFromERC20(path[0], msg.sender, FabulousLibrary.pairFor(factory, path[0], path[1]), amountIn);
    _swapSupportingFeeOnTransferTokens(path, address(this));
    uint256 amountOut = IERC20(WETH).balanceOf(address(this));
    require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
    IWETH(WETH).withdraw(amountOut);
    TransferHelpers._safeTransferEther(to, amountOut);
  }

  function swapETHForExactTokens(
    uint256 amountOut,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
    require(path[0] == WETH, "INVALID_PATH");
    amounts = FabulousLibrary.getAmountsIn(factory, amountOut, path);
    require(amounts[0] <= msg.value, "EXCESSIVE_INPUT_AMOUNT");
    IWETH(WETH).deposit{value: amounts[0]}();
    assert(IERC20(WETH).transfer(FabulousLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
    _swap(amounts, path, to);
    // refund dust eth, if any
    if (msg.value > amounts[0]) TransferHelpers._safeTransferEther(msg.sender, msg.value - amounts[0]);
  }

  // **** LIBRARY FUNCTIONS ****
  function quote(
    uint256 amountA,
    uint256 reserveA,
    uint256 reserveB
  ) public pure virtual override returns (uint256 amountB) {
    return FabulousLibrary.quote(amountA, reserveA, reserveB);
  }

  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) public pure virtual override returns (uint256 amountOut) {
    return FabulousLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
  }

  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut
  ) public pure virtual override returns (uint256 amountIn) {
    return FabulousLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
  }

  function getAmountsOut(uint256 amountIn, address[] memory path) public view virtual override returns (uint256[] memory amounts) {
    return FabulousLibrary.getAmountsOut(factory, amountIn, path);
  }

  function getAmountsIn(uint256 amountOut, address[] memory path) public view virtual override returns (uint256[] memory amounts) {
    return FabulousLibrary.getAmountsIn(factory, amountOut, path);
  }
}
