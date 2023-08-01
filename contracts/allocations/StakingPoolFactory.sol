pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./StakingPool.sol";
import "../helpers/TransferHelper.sol";

contract StakingPoolFactory is Ownable, AccessControl {
  using Address for address;

  event StakingPoolDeployed(address poolId, address owner, address token0, address token1, uint256 apy, uint8 tax, uint256 endsIn);

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

    emit StakingPoolDeployed(poolId, _msgSender(), token0, token1, apy, taxPercentage, endsIn);
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

  receive() external payable {}
}
