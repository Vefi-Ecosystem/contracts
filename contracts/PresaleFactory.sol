pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Presale.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";
import "./helpers/TransferHelper.sol";

contract PresaleFactory is Ownable, AccessControl {
  event PresaleCreated(
    address indexed presaleId,
    string metadataURI,
    address funder,
    uint256 salePrice,
    address indexed paymentToken,
    address indexed saleToken,
    uint256 startTime,
    uint256 endTime,
    uint256 minTotalPayment,
    uint256 maxTotalPayment,
    uint24 withdrawDelay
  );

  IPancakeRouter02 pancakeRouter;
  address USD;
  address public feeCollector;

  uint256 public usdFee;

  bytes32 public excludedFromFeeRole = keccak256(abi.encodePacked("EXCLUDED_FROM_FEE_ROLE"));

  constructor(
    address router,
    address _usd,
    uint16 _usdFee,
    address _feeCollector
  ) {
    USD = _usd;
    pancakeRouter = IPancakeRouter02(router);
    usdFee = uint256(_usdFee) * (10**ERC20(_usd).decimals());
    feeCollector = _feeCollector;
    _grantRole(excludedFromFeeRole, _msgSender());
  }

  function deploySale(
    string memory metadataURI,
    address newOwner,
    address funder,
    uint256 salePrice,
    address paymentToken,
    address saleToken,
    uint256 startTime,
    uint16 daysToLast,
    uint256 minTotalPayment,
    uint256 maxTotalPayment,
    uint256[] calldata claimTimes,
    uint8[] calldata pct,
    uint24 withdrawDelay
  ) external payable returns (address presaleId) {
    uint256 fee = getDeploymentFeeETHER(_msgSender());
    uint256 endTime = startTime + (uint256(daysToLast) * 1 days);
    require(msg.value >= fee, "fee");
    bytes memory byteCode = abi.encodePacked(
      type(Presale).creationCode,
      abi.encode(metadataURI, funder, salePrice, paymentToken, saleToken, startTime, endTime, maxTotalPayment)
    );
    bytes32 salt = keccak256(abi.encodePacked(_msgSender(), funder, block.timestamp));

    assembly ("memory-safe") {
      presaleId := create2(0, add(byteCode, 32), mload(byteCode), salt)
      if iszero(extcodesize(presaleId)) {
        revert(0, "could not deploy sale contract")
      }
    }

    Presale pSale = Presale(presaleId);

    pSale.setMinTotalPayment(minTotalPayment);
    pSale.setWithdrawDelay(withdrawDelay);

    if (claimTimes.length > 0) {
      pSale.setCliffPeriod(claimTimes, pct);
    } else {
      pSale.setLinearVestingEndTime(pSale.withdrawTime() + 1);
    }

    if (fee > 0) {
      TransferHelpers._safeTransferEther(feeCollector, fee);
    }

    pSale.transferOwnership(newOwner);

    emit PresaleCreated(
      presaleId,
      metadataURI,
      funder,
      salePrice,
      paymentToken,
      saleToken,
      startTime,
      endTime,
      minTotalPayment,
      maxTotalPayment,
      withdrawDelay
    );
  }

  function setUSDFee(uint16 _usdFee) external onlyOwner {
    usdFee = uint256(_usdFee) * (10**ERC20(USD).decimals());
  }

  function getDeploymentFeeETHER(address payer) public view returns (uint256 deploymentFee) {
    if (hasRole(excludedFromFeeRole, payer)) deploymentFee = 0;
    else {
      IPancakeFactory factory = IPancakeFactory(pancakeRouter.factory());
      IPancakePair usdWETHPair = IPancakePair(factory.getPair(USD, pancakeRouter.WETH()));
      (uint112 reserve0, uint112 reserve1, ) = usdWETHPair.getReserves();
      (uint112 reserveA, uint112 reserveB) = usdWETHPair.token0() == USD ? (reserve0, reserve1) : (reserve1, reserve0);
      deploymentFee = pancakeRouter.quote(usdFee, reserveA, reserveB);
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
