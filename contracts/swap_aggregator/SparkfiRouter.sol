pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ISparkfiRouter.sol";
import "./interfaces/ISparkfiAdapter.sol";
import "./interfaces/IWETH.sol";
import "../helpers/TransferHelper.sol";

contract SparkfiRouter is ISparkfiRouter, AccessControl, Ownable, ReentrancyGuard {
  using Address for address;

  address public FEE_CLAIMER;
  address[] public adapters;
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
    address _weth
  ) {
    adapters = _adapters;
    FEE_CLAIMER = _feeClaimer;
    WETH = _weth;
    _grantRole(maintainerRole, _msgSender());
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

  function _swap(
    Trade calldata trade,
    address from,
    address to,
    uint256 fee
  ) internal returns (uint256) {
    address[] memory adpts = adapters;
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
      Query memory _bestQuery = query(trade.path[i], trade.path[i + 1], amounts[i]);
      amounts[i + 1] = _bestQuery.amountOut;
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
}
