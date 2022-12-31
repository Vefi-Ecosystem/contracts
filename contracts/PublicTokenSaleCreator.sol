pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./helpers/TransferHelper.sol";
import "./misc/VestingSchedule.sol";
import "./misc/SaleInfo.sol";
import "./Presale.sol";
import "./PresaleVestable.sol";

contract PublicTokenSaleCreator is ReentrancyGuard, Pausable, Ownable, AccessControl {
  using Address for address;
  using SafeMath for uint256;

  address[] public allTokenSales;
  bytes32 public withdrawerRole = keccak256(abi.encodePacked("WITHDRAWER_ROLE"));

  uint8 public feePercentage;
  uint256 public saleCreationFee;

  event TokenSaleItemCreated(
    address presaleAddress,
    address token,
    uint256 tokensForSale,
    uint256 softcap,
    uint256 hardcap,
    uint256 tokensPerEther,
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 saleEndTime,
    address proceedsTo,
    address admin
  );

  constructor(uint8 _feePercentage, uint256 _saleCreationFee) {
    _grantRole(withdrawerRole, _msgSender());
    feePercentage = _feePercentage;
    saleCreationFee = _saleCreationFee;
  }

  function createPresale(PresaleInfo memory saleInfo) external payable whenNotPaused nonReentrant returns (address presaleAddress) {
    uint256 endTime = saleInfo.saleStartTime.add(saleInfo.daysToLast);

    {
      require(msg.value >= saleCreationFee, "fee");
      require(saleInfo.token.isContract(), "must_be_contract_address");
      require(
        saleInfo.saleStartTime > block.timestamp && saleInfo.saleStartTime.sub(block.timestamp) >= 24 hours,
        "sale_must_begin_in_at_least_24_hours"
      );
    }

    {
      bytes memory bytecode = abi.encodePacked(
        type(Presale).creationCode,
        abi.encode(
          saleInfo.token,
          saleInfo.proceedsTo,
          saleInfo.tokensForSale,
          saleInfo.softcap,
          saleInfo.hardcap,
          saleInfo.tokensPerEther,
          saleInfo.saleStartTime,
          endTime,
          feePercentage,
          saleInfo.minContributionEther,
          saleInfo.maxContributionEther,
          saleInfo.admin
        )
      );
      bytes32 salt = keccak256(abi.encodePacked(block.timestamp, address(this), saleInfo.admin, saleInfo.token));

      assembly {
        presaleAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        if iszero(extcodesize(presaleAddress)) {
          revert(0, 0)
        }
      }
      require(IERC20(saleInfo.token).allowance(_msgSender(), address(this)) >= saleInfo.tokensForSale, "not_enough_allowance_given");
      TransferHelpers._safeTransferFromERC20(saleInfo.token, _msgSender(), presaleAddress, saleInfo.tokensForSale);
    }

    {
      allTokenSales.push(presaleAddress);
      emit TokenSaleItemCreated(
        presaleAddress,
        saleInfo.token,
        saleInfo.tokensForSale,
        saleInfo.softcap,
        saleInfo.hardcap,
        saleInfo.tokensPerEther,
        saleInfo.minContributionEther,
        saleInfo.maxContributionEther,
        saleInfo.saleStartTime,
        endTime,
        saleInfo.proceedsTo,
        saleInfo.admin
      );
    }
  }

  function createPresaleVestable(PresaleInfo memory saleInfo, VestingSchedule[] memory vestingSchedule)
    external
    payable
    whenNotPaused
    nonReentrant
    returns (address presaleAddress)
  {
    uint256 endTime = saleInfo.saleStartTime.add(saleInfo.daysToLast);

    {
      require(msg.value >= saleCreationFee, "fee");
      require(saleInfo.token.isContract(), "must_be_contract_address");
      require(
        saleInfo.saleStartTime > block.timestamp && saleInfo.saleStartTime.sub(block.timestamp) >= 24 hours,
        "sale_must_begin_in_at_least_24_hours"
      );
    }

    {
      bytes memory bytecode = abi.encodePacked(
        type(PresaleVestable).creationCode,
        abi.encode(
          saleInfo.token,
          saleInfo.proceedsTo,
          saleInfo.tokensForSale,
          saleInfo.softcap,
          saleInfo.hardcap,
          saleInfo.tokensPerEther,
          saleInfo.saleStartTime,
          endTime,
          feePercentage,
          saleInfo.minContributionEther,
          saleInfo.maxContributionEther,
          saleInfo.admin,
          vestingSchedule
        )
      );
      bytes32 salt = keccak256(abi.encodePacked(block.timestamp, address(this), saleInfo.admin, saleInfo.token));

      assembly {
        presaleAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        if iszero(extcodesize(presaleAddress)) {
          revert(0, 0)
        }
      }
      require(IERC20(saleInfo.token).allowance(_msgSender(), address(this)) >= saleInfo.tokensForSale, "not_enough_allowance_given");
      TransferHelpers._safeTransferFromERC20(saleInfo.token, _msgSender(), presaleAddress, saleInfo.tokensForSale);
    }

    {
      allTokenSales.push(presaleAddress);
      emit TokenSaleItemCreated(
        presaleAddress,
        saleInfo.token,
        saleInfo.tokensForSale,
        saleInfo.softcap,
        saleInfo.hardcap,
        saleInfo.tokensPerEther,
        saleInfo.minContributionEther,
        saleInfo.maxContributionEther,
        saleInfo.saleStartTime,
        endTime,
        saleInfo.proceedsTo,
        saleInfo.admin
      );
    }
  }

  function withdrawEther(address to) external {
    require(hasRole(withdrawerRole, _msgSender()) || _msgSender() == owner(), "only_withdrawer_or_owner");
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function retrieveERC20(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    require(_token.isContract(), "must_be_contract_address");
    TransferHelpers._safeTransferERC20(_token, _to, _amount);
  }

  function setFeePercentage(uint8 _feePercentage) external onlyOwner {
    feePercentage = _feePercentage;
  }

  function setSaleCreationFee(uint256 _saleCreationFee) external onlyOwner {
    saleCreationFee = _saleCreationFee;
  }

  receive() external payable {}
}
