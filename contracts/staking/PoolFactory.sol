pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Pool.sol";
import "../helpers/TransferHelper.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakePair.sol";

contract PoolFactory is Ownable, AccessControl {
  using Address for address;
  uint256 public deploymentFeeUSD;
  bytes32 public excludedFromFeeRole = keccak256(abi.encodePacked("EXCLUDED_FROM_FEE_ROLE"));

  IPancakeRouter02 pancakeRouter;
  address USD;
  address public feeCollector;

  event PoolDeployed(
    address poolId,
    address owner,
    address stakeToken,
    address rewardToken,
    uint256 rewardsByBlock,
    uint16 stakeTax,
    uint16 unstakeTax,
    uint256 startBlock,
    uint256 endBlock
  );

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
    bytes memory creationCode,
    address stakeToken,
    address rewardToken,
    uint256 rewardsByBlock,
    uint256 rewardsUnlockBlock,
    uint256 startBlock,
    uint256 endBlock,
    uint16 stakeTax,
    uint16 unstakeTax,
    address newOwner,
    address taxReceiver,
    bool fundImmediately,
    uint256 fundAmount
  ) external payable returns (address poolId) {
    uint256 deploymentFee = getDeploymentFeeETHER(_msgSender());
    require(msg.value >= deploymentFee, "fee");

    bytes memory bytecode = abi.encodePacked(
      creationCode,
      abi.encode(stakeToken, rewardToken, rewardsByBlock, rewardsUnlockBlock, startBlock, endBlock, stakeTax, unstakeTax, newOwner, taxReceiver)
    );

    bytes32 salt = keccak256(abi.encodePacked(stakeToken, rewardToken, block.timestamp));

    assembly {
      poolId := create2(0, add(bytecode, 32), mload(bytecode), salt)
      if iszero(extcodesize(poolId)) {
        revert(0, 0)
      }
    }

    if (fundImmediately) {
      require(startBlock <= block.timestamp, "pool must start immediately for it be funded");
      require(fundAmount > 0, "fund amount must be greater than 0");

      TransferHelpers._safeTransferFromERC20(rewardToken, _msgSender(), address(this), fundAmount);
      Pool(poolId).fundPool(fundAmount);
    }

    if (deploymentFee > 0) TransferHelpers._safeTransferEther(feeCollector, deploymentFee);

    emit PoolDeployed(poolId, newOwner, stakeToken, rewardToken, rewardsByBlock, stakeTax, unstakeTax, startBlock, endBlock);
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
