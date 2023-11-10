pragma solidity ^0.8.0;

import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakePair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FabulousExchangeMultiHopsRouter {
  IPancakeFactory public factory;
  IPancakeRouter02 public router;

  constructor(IPancakeFactory _factory, IPancakeRouter02 _router) {
    factory = _factory;
    router = _router;
  }

  function _getPossiblePath(address tokenA, address tokenB) private view returns (address[] memory) {
    address firstPair = factory.getPair(tokenA, tokenB);
    address[] memory paths;
    uint256 allPairsLength = factory.allPairsLength();

    if (firstPair != address(0)) {
      paths[0] = tokenA;
      paths[1] = tokenB;
      return paths;
    }

    address[] memory allTokenAPartners;

    for (uint256 i = 0; i < allPairsLength; i++) {
      address pairAddress = factory.allPairs(i);
      IPancakePair pair = IPancakePair(pairAddress);

      if (pair.token0() == tokenA || pair.token1() == tokenA) {
        allTokenAPartners[allTokenAPartners.length] = pair.token0() == tokenA ? pair.token1() : pair.token0();
      }
    }

    address tokenAB;

    for (uint256 i = 0; i < allTokenAPartners.length; i++) {
      address pair = factory.getPair(tokenB, allTokenAPartners[i]);

      if (pair != address(0)) {
        tokenAB = allTokenAPartners[i];
        break;
      }
    }

    paths[0] = tokenA;
    paths[1] = tokenAB;
    paths[2] = tokenB;

    return paths;
  }

  function swapExactTokensForTokens(
    address tokenA,
    address tokenB,
    uint256 amountIn,
    uint256 amountOutMin,
    address to,
    uint256 deadline
  ) external {
    address[] memory path = _getPossiblePath(tokenA, tokenB);

    if (path.length == 2) {
      router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256 AMOUNTIN = token0 == tokenA ? amountIn : IERC20(token0).balanceOf(address(this));
        uint256[] memory amounts = router.getAmountsOut(AMOUNTIN, innerPath);
        uint256 AMOUNTOUTMIN = token1 == tokenB ? amountOutMin : amounts[amounts.length - 1];
        address recipient = i == path.length - 1 ? to : address(this);

        router.swapExactTokensForTokens(AMOUNTIN, AMOUNTOUTMIN, innerPath, recipient, deadline);
      }
    }
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    address tokenA,
    address tokenB,
    uint256 amountIn,
    uint256 amountOutMin,
    address to,
    uint256 deadline
  ) external {
    address[] memory path = _getPossiblePath(tokenA, tokenB);

    if (path.length == 2) {
      router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256 AMOUNTIN = token0 == tokenA ? amountIn : IERC20(token0).balanceOf(address(this));
        uint256[] memory amounts = router.getAmountsOut(AMOUNTIN, innerPath);
        uint256 AMOUNTOUTMIN = token1 == tokenB ? amountOutMin : amounts[amounts.length - 1];
        address recipient = i == path.length - 1 ? to : address(this);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(AMOUNTIN, AMOUNTOUTMIN, innerPath, recipient, deadline);
      }
    }
  }

  function swapTokensForExactTokens(
    address tokenA,
    address tokenB,
    uint256 amountOut,
    uint256 amountInMax,
    address to,
    uint256 deadline
  ) external {
    address[] memory path = _getPossiblePath(tokenA, tokenB);

    if (path.length == 2) {
      router.swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256[] memory _amountsOut = router.getAmountsOut(token0 == tokenA ? amountInMax : IERC20(token0).balanceOf(address(this)), innerPath);

        uint256 AMOUNTOUT = token1 == tokenB ? amountOut : _amountsOut[0];
        uint256[] memory amounts = router.getAmountsIn(AMOUNTOUT, innerPath);
        uint256 AMOUNTINMAX = token0 == tokenA ? amountInMax : amounts[0];
        address recipient = i == path.length - 1 ? to : address(this);

        router.swapTokensForExactTokens(AMOUNTOUT, AMOUNTINMAX, innerPath, recipient, deadline);
      }
    }
  }

  function swapExactETHForTokens(
    address token,
    uint256 amountOutMin,
    address to,
    uint256 deadline
  ) external payable {
    address[] memory path = _getPossiblePath(router.WETH(), token);

    if (path.length == 2) {
      router.swapExactETHForTokens(amountOutMin, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256 AMOUNTIN = token0 == router.WETH() ? msg.value : IERC20(token0).balanceOf(address(this));
        uint256[] memory amounts = router.getAmountsOut(AMOUNTIN, innerPath);
        uint256 AMOUNTOUTMIN = token1 == token ? amountOutMin : amounts[amounts.length - 1];
        address recipient = i == path.length - 1 ? to : address(this);

        if (token0 == router.WETH()) {
          router.swapExactETHForTokens(AMOUNTOUTMIN, innerPath, recipient, deadline);
        } else {
          router.swapExactTokensForTokens(AMOUNTIN, AMOUNTOUTMIN, innerPath, recipient, deadline);
        }
      }
    }
  }

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    address token,
    uint256 amountOutMin,
    address to,
    uint256 deadline
  ) external payable {
    address[] memory path = _getPossiblePath(router.WETH(), token);

    if (path.length == 2) {
      router.swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256 AMOUNTIN = token0 == router.WETH() ? msg.value : IERC20(token0).balanceOf(address(this));
        uint256[] memory amounts = router.getAmountsOut(AMOUNTIN, innerPath);
        uint256 AMOUNTOUTMIN = token1 == token ? amountOutMin : amounts[amounts.length - 1];
        address recipient = i == path.length - 1 ? to : address(this);

        if (token0 == router.WETH()) {
          router.swapExactETHForTokensSupportingFeeOnTransferTokens(AMOUNTOUTMIN, innerPath, recipient, deadline);
        } else {
          router.swapExactTokensForTokensSupportingFeeOnTransferTokens(AMOUNTIN, AMOUNTOUTMIN, innerPath, recipient, deadline);
        }
      }
    }
  }

  function swapTokensForExactETH(
    address token,
    uint256 amountOut,
    uint256 amountInMax,
    address to,
    uint256 deadline
  ) external {
    address[] memory path = _getPossiblePath(token, router.WETH());

    if (path.length == 2) {
      router.swapTokensForExactETH(amountOut, amountInMax, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256[] memory _amountsOut = router.getAmountsOut(token0 == token ? amountInMax : IERC20(token0).balanceOf(address(this)), innerPath);

        uint256 AMOUNTOUT = token1 == router.WETH() ? amountOut : _amountsOut[0];
        uint256[] memory amounts = router.getAmountsIn(AMOUNTOUT, innerPath);
        uint256 AMOUNTINMAX = token0 == token ? amountInMax : amounts[0];
        address recipient = i == path.length - 1 ? to : address(this);

        if (token1 == router.WETH()) {
          router.swapTokensForExactETH(AMOUNTOUT, AMOUNTINMAX, innerPath, recipient, deadline);
        } else {
          router.swapTokensForExactTokens(AMOUNTOUT, AMOUNTINMAX, innerPath, recipient, deadline);
        }
      }
    }
  }

  function swapExactTokensForETH(
    address token,
    uint256 amountIn,
    uint256 amountOutMin,
    address to,
    uint256 deadline
  ) external {
    address[] memory path = _getPossiblePath(token, router.WETH());

    if (path.length == 2) {
      router.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
    } else {
      for (uint256 i = 1; i < path.length; i++) {
        address token0 = path[i - 1];
        address token1 = path[i];
        address[] memory innerPath;

        innerPath[0] = token0;
        innerPath[1] = token1;

        uint256[] memory _amountsOut = router.getAmountsOut(token0 == token ? amountIn : IERC20(token0).balanceOf(address(this)), innerPath);

        uint256 AMOUNTOUT = token1 == router.WETH() ? amountOutMin : _amountsOut[0];
        uint256[] memory amounts = router.getAmountsIn(AMOUNTOUT, innerPath);
        uint256 AMOUNTIN = token0 == token ? amountIn : amounts[0];
        address recipient = i == path.length - 1 ? to : address(this);

        if (token1 == router.WETH()) {
          router.swapExactTokensForETH(AMOUNTIN, AMOUNTOUT, innerPath, recipient, deadline);
        } else {
          router.swapExactTokensForTokens(AMOUNTIN, AMOUNTOUT, innerPath, recipient, deadline);
        }
      }
    }
  }
}
