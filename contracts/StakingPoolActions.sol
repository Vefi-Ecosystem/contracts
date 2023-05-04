pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./StakingPool.sol";
import "./helpers/TransferHelper.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";

contract StakingPoolActions is Ownable, AccessControl {
  using Address for address;
  uint256 public deploymentFeeUSD;
  bytes32 public excludedFromFeeRole = keccak256(abi.encodePacked("EXCLUDED_FROM_FEE_ROLE"));

  IPancakeRouter02 pancakeRouter;
  address USD;
  address public feeCollector;

  event StakingPoolDeployed(address poolId, address owner, address token0, address token1, uint256 apy, uint8 tax, uint256 endsIn);

  constructor(
    address router,
    uint16 _deploymentFee,
    address _usd,
    address _feeCollector
  ) {
    USD = _usd;
    pancakeRouter = IPancakeRouter02(router);
    deploymentFeeUSD = uint256(_deploymentFee) * (10**ERC20(_usd).decimals());
    feeCollector = _feeCollector;
    _grantRole(excludedFromFeeRole, _msgSender());
  }

  function deployStakingPool(
    address token0,
    address token1,
    uint16 apy,
    uint8 taxPercentage,
    address taxRecipient,
    uint256 withdrawalIntervals,
    uint256 initialAmount,
    int256 daysToLast
  ) external payable returns (address poolId) {
    uint256 deploymentFee = getDeploymentFeeETHER(_msgSender());
    if (token1 == address(0)) {
      uint256 a = initialAmount + deploymentFee;
      require(msg.value >= a, "fee or amount for ether reward");
    } else {
      require(msg.value >= deploymentFee, "fee");
    }

    uint256 endsIn = block.timestamp + (uint256(daysToLast) * 1 days);
    bytes memory bytecode = abi.encodePacked(
      type(StakingPool).creationCode,
      abi.encode(_msgSender(), token0, token1, apy, taxPercentage, taxRecipient, withdrawalIntervals, endsIn)
    );
    bytes32 salt = keccak256(abi.encodePacked(token0, token1, apy, _msgSender(), block.timestamp));

    assembly {
      poolId := create2(0, add(bytecode, 32), mload(bytecode), salt)
      if iszero(extcodesize(poolId)) {
        revert(0, 0)
      }
    }
    if (token1 != address(0) && token1.isContract()) {
      require(IERC20(token1).allowance(_msgSender(), address(this)) >= initialAmount, "not enough allowance");
      TransferHelpers._safeTransferFromERC20(token1, _msgSender(), poolId, initialAmount);
    } else {
      TransferHelpers._safeTransferEther(poolId, initialAmount);
    }

    if (deploymentFee > 0) TransferHelpers._safeTransferEther(feeCollector, deploymentFee);

    emit StakingPoolDeployed(poolId, _msgSender(), token0, token1, apy, taxPercentage, endsIn);
  }

  function setUSDFee(uint16 _usdFee) external onlyOwner {
    deploymentFeeUSD = uint256(_usdFee) * (10**ERC20(USD).decimals());
  }

  function getDeploymentFeeETHER(address payer) public view returns (uint256 deploymentFee) {
    if (hasRole(excludedFromFeeRole, payer)) deploymentFee = 0;
    else {
      IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
      IPancakePair usdWETHPair = IPancakePair(factory.getPair(USD, pancakeRouter.WETH()));
      (uint112 reserve0, uint112 reserve1, ) = usdWETHPair.getReserves();
      (uint112 reserveA, uint112 reserveB) = usdWETHPair.token0() == USD ? (reserve0, reserve1) : (reserve1, reserve0);
      deploymentFee = pancakeRouter.quote(deploymentFeeUSD, reserveA, reserveB);
    }
  }

  function withdrawToken(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function withdrawEther(address to) external onlyOwner {
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function setFeeCollector(address _feeCollector) external onlyOwner {
    feeCollector = _feeCollector;
  }

  function excludeFromFee(address account) external onlyOwner {
    require(!hasRole(excludedFromFeeRole, account));
    _grantRole(excludedFromFeeRole, account);
  }

  function includeInFee(address account) external onlyOwner {
    require(hasRole(excludedFromFeeRole, account));
    _revokeRole(excludedFromFeeRole, account);
  }

  receive() external payable {}
}
