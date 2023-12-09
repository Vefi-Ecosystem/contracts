pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ISparkfiRouter.sol";
import "./interfaces/ISparkfiAdapter.sol";
import "./interfaces/IWETH.sol";
import "../helpers/TransferHelper.sol";
import "./lib/ViewUtils.sol";

contract SparkfiRouter is ISparkfiRouter, AccessControl, Ownable, ReentrancyGuard {
  using Address for address;
  using OfferUtils for Offer;

  address public FEE_CLAIMER;
  address[] public adapters;
  address[] public TRUSTED_TOKENS;
  address public WETH;
  uint256 public constant FEE_DENOM = 1e4;
  uint256 public MIN_FEE = 0;

  bytes32 public maintainerRole = keccak256(abi.encodePacked("MAINTAINER_ROLE"));
  bytes4 private adapterSwapSelector = bytes4(keccak256(bytes("swap(address,address,address,uint256,uint256)")));

  event UpdatedMinFee(uint256 newMinfee);
  event RouterSwap(address indexed tokenIn, address indexed tokenOut, address to, uint256 amountIn, uint256 amountOut);
  event SetAdapters(address[] adapters);

  constructor(
    address[] memory _adapters,
    address _feeClaimer,
    address _weth,
    address[] memory _trustedTokens
  ) {
    adapters = _adapters;
    FEE_CLAIMER = _feeClaimer;
    WETH = _weth;
    _grantRole(maintainerRole, _msgSender());
    TRUSTED_TOKENS = _trustedTokens;
    TRUSTED_TOKENS.push(_weth);
  }

  modifier onlyMaintainer() {
    require(hasRole(maintainerRole, _msgSender()), "only maintainer");
    _;
  }

  function setMaintainer(address maintainer) external onlyOwner {
    require(!hasRole(maintainerRole, maintainer), "already maintainer");
    _grantRole(maintainerRole, maintainer);
  }

  function removeMaintainer(address maintainer) external onlyOwner {
    require(hasRole(maintainerRole, maintainer), "does not have maintainer role");
    _grantRole(maintainerRole, maintainer);
  }

  function setFee(uint256 _minFee) external onlyMaintainer {
    MIN_FEE = _minFee;
    emit UpdatedMinFee(_minFee);
  }

  function setFeeClaimer(address _feeClaimer) external onlyMaintainer {
    FEE_CLAIMER = _feeClaimer;
  }

  function setAdapters(address[] memory _adapters) external onlyMaintainer {
    adapters = _adapters;
    emit SetAdapters(_adapters);
  }

  receive() external payable {}

  function _applyFee(uint256 _amountIn, uint256 _fee) internal view returns (uint256) {
    require(_fee >= MIN_FEE, "not enough fee");
    return (_amountIn * (FEE_DENOM - _fee)) / FEE_DENOM;
  }

  function _returnTokensTo(
    address _token,
    uint256 _amount,
    address _to
  ) internal {
    if (address(this) != _to) {
      if (_token == address(0)) {
        TransferHelpers._safeTransferEther(_to, _amount);
      } else {
        TransferHelpers._safeTransferERC20(_token, _to, _amount);
      }
    }
  }

  function query(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) public view returns (Query memory _bestQuery) {
    address[] memory adpts = adapters;
    for (uint256 i = 0; i < adpts.length; i++) {
      uint256 amountOut = ISparkfiAdapter(adpts[i]).query(tokenIn, tokenOut, amountIn);

      if (i == 0 || amountOut > _bestQuery.amountOut) {
        _bestQuery = Query(adpts[i], tokenIn, tokenOut, amountOut);
      }
    }
  }

  function queryNoSplit(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint8[] calldata _options
  ) public view override returns (Query memory) {
    Query memory bestQuery;
    for (uint8 i; i < _options.length; i++) {
      address _adapter = adapters[_options[i]];
      uint256 amountOut = ISparkfiAdapter(_adapter).query(_tokenIn, _tokenOut, _amountIn);
      if (i == 0 || amountOut > bestQuery.amountOut) {
        bestQuery = Query(_adapter, _tokenIn, _tokenOut, amountOut);
      }
    }

    return bestQuery;
  }

  function adptersLength() external view returns (uint256 length) {
    length = adapters.length;
  }

  function _swap(
    Trade calldata trade,
    address from,
    address to,
    uint256 fee
  ) internal returns (uint256) {
    address[] memory adpts = trade.adapters;
    uint256[] memory amounts = new uint256[](trade.path.length);
    if (fee > 0 || MIN_FEE > 0) {
      amounts[0] = _applyFee(trade.amountIn, fee);
      if (from != address(this)) {
        TransferHelpers._safeTransferFromERC20(trade.path[0], from, FEE_CLAIMER, trade.amountIn - amounts[0]);
      } else {
        TransferHelpers._safeTransferERC20(trade.path[0], FEE_CLAIMER, trade.amountIn - amounts[0]);
      }
    } else {
      amounts[0] = trade.amountIn;
    }

    if (from != address(this)) {
      TransferHelpers._safeTransferFromERC20(trade.path[0], from, adpts[0], amounts[0]);
    } else {
      TransferHelpers._safeTransferERC20(trade.path[0], adpts[0], amounts[0]);
    }

    for (uint256 i = 0; i < adpts.length; i++) {
      amounts[i + 1] = ISparkfiAdapter(adpts[i]).query(trade.path[i], trade.path[i + 1], amounts[i]);
    }

    require(amounts[amounts.length - 1] >= trade.amountOut, "insufficient output amount");
    for (uint256 i = 0; i < adpts.length; i++) {
      address targetAddress = i < adpts.length - 1 ? adpts[i + 1] : to;
      address adapter = adpts[i];
      adapter.functionCall(abi.encodeWithSelector(adapterSwapSelector, trade.path[i], trade.path[i + 1], targetAddress, amounts[i], amounts[i + 1]));
    }

    emit RouterSwap(trade.path[0], trade.path[trade.path.length - 1], to, trade.amountIn, amounts[amounts.length - 1]);
    return amounts[amounts.length - 1];
  }

  function swap(
    Trade calldata trade,
    address to,
    uint256 fee
  ) external payable {
    if (trade.path[0] == WETH) {
      require(trade.amountIn >= msg.value, "trade.amountIn must be at least equal to msg.value");
      IWETH(WETH).deposit{value: trade.amountIn}();
      _swap(trade, address(this), to, fee);
    } else if (trade.path[trade.path.length - 1] == WETH) {
      uint256 returnAmount = _swap(trade, _msgSender(), address(this), fee);
      IWETH(WETH).withdraw(returnAmount);
      _returnTokensTo(address(0), returnAmount, to);
    } else {
      _swap(trade, _msgSender(), to, fee);
    }
  }

  function findBestPathWithGas(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint256 _maxSteps,
    uint256 _gasPrice
  ) external view override returns (FormattedOffer memory) {
    require(_maxSteps > 0 && _maxSteps < 5, "invalid max steps");
    Offer memory queries = OfferUtils.newOffer(_amountIn, _tokenIn);
    uint256 gasPriceInExitTkn = _gasPrice > 0 ? getGasPriceInExitTkn(_gasPrice, _tokenOut) : 0;
    queries = _findBestPath(_amountIn, _tokenIn, _tokenOut, _maxSteps, queries, gasPriceInExitTkn);
    if (queries.adapters.length == 0) {
      queries.amounts = "";
      queries.path = "";
    }
    return queries.format();
  }

  // Find the market price between gas-asset(native) and token-out and express gas price in token-out
  function getGasPriceInExitTkn(uint256 _gasPrice, address _tokenOut) internal view returns (uint256 price) {
    // Avoid low-liquidity price appreciation (https://github.com/yieldyak/yak-aggregator/issues/20)
    FormattedOffer memory gasQuery = findBestPath(1e18, WETH, _tokenOut, 2);
    if (gasQuery.path.length != 0) {
      // Leave result in nWei to preserve precision for assets with low decimal places
      price = (gasQuery.amounts[gasQuery.amounts.length - 1] * _gasPrice) / 1e9;
    }
  }

  /**
   * Return path with best returns between two tokens
   */
  function findBestPath(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint256 _maxSteps
  ) public view override returns (FormattedOffer memory) {
    require(_maxSteps > 0 && _maxSteps < 5, "invalid max steps");
    Offer memory queries = OfferUtils.newOffer(_amountIn, _tokenIn);
    queries = _findBestPath(_amountIn, _tokenIn, _tokenOut, _maxSteps, queries, 0);
    // If no paths are found return empty struct
    if (queries.adapters.length == 0) {
      queries.amounts = "";
      queries.path = "";
    }
    return queries.format();
  }

  function _findBestPath(
    uint256 _amountIn,
    address _tokenIn,
    address _tokenOut,
    uint256 _maxSteps,
    Offer memory _queries,
    uint256 _tknOutPriceNwei
  ) internal view returns (Offer memory) {
    Offer memory bestOption = _queries.clone();
    uint256 bestAmountOut;
    uint256 gasEstimate;
    bool withGas = _tknOutPriceNwei != 0;

    // First check if there is a path directly from tokenIn to tokenOut
    Query memory queryDirect = query(_tokenIn, _tokenOut, _amountIn);

    if (queryDirect.amountOut != 0) {
      if (withGas) {
        gasEstimate = ISparkfiAdapter(queryDirect.adapter).swapGasEstimate();
      }
      bestOption.addToTail(queryDirect.amountOut, queryDirect.adapter, queryDirect.tokenOut, gasEstimate);
      bestAmountOut = queryDirect.amountOut;
    }
    // Only check the rest if they would go beyond step limit (Need at least 2 more steps)
    if (_maxSteps > 1 && _queries.adapters.length / 32 <= _maxSteps - 2) {
      // Check for paths that pass through trusted tokens
      for (uint256 i = 0; i < TRUSTED_TOKENS.length; i++) {
        if (_tokenIn == TRUSTED_TOKENS[i]) {
          continue;
        }
        // Loop through all adapters to find the best one for swapping tokenIn for one of the trusted tokens
        Query memory bestSwap = query(_tokenIn, TRUSTED_TOKENS[i], _amountIn);
        if (bestSwap.amountOut == 0) {
          continue;
        }
        // Explore options that connect the current path to the tokenOut
        Offer memory newOffer = _queries.clone();
        if (withGas) {
          gasEstimate = ISparkfiAdapter(bestSwap.adapter).swapGasEstimate();
        }
        newOffer.addToTail(bestSwap.amountOut, bestSwap.adapter, bestSwap.tokenOut, gasEstimate);
        newOffer = _findBestPath(bestSwap.amountOut, TRUSTED_TOKENS[i], _tokenOut, _maxSteps, newOffer, _tknOutPriceNwei); // Recursive step
        address tokenOut = newOffer.getTokenOut();
        uint256 amountOut = newOffer.getAmountOut();
        // Check that the last token in the path is the tokenOut and update the new best option if neccesary
        if (_tokenOut == tokenOut && amountOut > bestAmountOut) {
          if (newOffer.gasEstimate > bestOption.gasEstimate) {
            uint256 gasCostDiff = (_tknOutPriceNwei * (newOffer.gasEstimate - bestOption.gasEstimate)) / 1e9;
            uint256 priceDiff = amountOut - bestAmountOut;
            if (gasCostDiff > priceDiff) {
              continue;
            }
          }
          bestAmountOut = amountOut;
          bestOption = newOffer;
        }
      }
    }
    return bestOption;
  }
}
