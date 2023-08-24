pragma solidity ^0.8.0;

import "./Presale.sol";
import "../interfaces/IAllocator.sol";

contract AllocationSale is Presale {
  IAllocator public allocator;

  constructor(
    string memory _metadataURI,
    address _funder,
    uint256 _salePrice,
    ERC20 _paymentToken,
    ERC20 _saleToken,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _maxTotalPayment,
    address _taxCollector,
    uint16 _taxPercentage,
    address _taxSetter,
    IAllocator _allocator
  )
    Presale(
      _metadataURI,
      _funder,
      _salePrice,
      _paymentToken,
      _saleToken,
      _startTime,
      _endTime,
      _maxTotalPayment,
      _taxCollector,
      _taxPercentage,
      _taxSetter
    )
  {
    allocator = _allocator;
  }

  function getPaymentAllocationForAccount(address account) public view returns (uint256) {
    uint256 totalWeight = allocator.totalStaked();
    uint256 userWeight = allocator.userWeight(account);
    require(totalWeight > 0, "total weight is 0");

    if (userWeight < allocator.guaranteedAllocationStart()) {
      return 0;
    }

    uint256 saleTokenAllocation = (((saleAmount * salePrice) / SALE_PRICE_DECIMALS) * 4) / totalWeight;
    return saleTokenAllocation * (userWeight / 10**18);
  }

  function getMaxPayment(address account) public view returns (uint256) {
    uint256 max = getPaymentAllocationForAccount(account);

    if (maxTotalPayment < max) {
      max = maxTotalPayment;
    }
    return max - paymentReceived[account];
  }

  function purchase(uint256 paymentAmount) public override onlyDuringSale {
    require(whitelistRootHash == 0, "use whitelistedPurchase");
    uint256 remaining = getMaxPayment(_msgSender());
    _purchase(paymentAmount, remaining);
  }

  function withdrawGiveaway(bytes32[] calldata merkleProof) public override onlyAfterSale nonReentrant {
    address user = _msgSender();
    require(salePrice == 0, "not a giveaway");
    require(whitelistRootHash == 0 || checkWhitelist(user, merkleProof), "proof invalid");

    if (!hasWithdrawn[user]) {
      uint256 value = getUserStakeValue(user);
      claimable[user] = value;
      totalPurchased[user] = value;
    }
    uint256 saleTokenOwed = getCurrentClaimableToken(user);

    _withdraw(saleTokenOwed);
    require(saleTokenOwed != 0, "withdraw giveaway amount 0");
  }

  function getUserStakeValue(address user) public view returns (uint256) {
    uint256 userWeight = allocator.userWeight(user);
    uint256 totalWeight = allocator.totalStaked();
    require(totalWeight > 0, "total weight is 0");

    return ((saleAmount * 4) / totalWeight) * (userWeight / 10**18);
  }
}
