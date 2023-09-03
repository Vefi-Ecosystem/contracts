pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Purchasable.sol";
import "./Fundable.sol";
import "./Vestable.sol";
import "./Whitelistable.sol";

contract Presale is Purchasable, Fundable, Vestable, Whitelistable {
  using SafeMath for uint256;
  mapping(address => uint256) public claimable;
  mapping(address => uint256) public totalPurchased;

  string public metadataURI;

  event EmergencyWithdrawal(address indexed user);
  event MetadataURIChanged(string metadataURI);

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
    address _taxSetter
  )
    Purchasable(_paymentToken, _salePrice, _maxTotalPayment)
    Vestable(_endTime)
    Fundable(_paymentToken, _saleToken, _startTime, _endTime, _funder, _taxCollector, _taxPercentage, _taxSetter)
    Whitelistable()
  {
    metadataURI = _metadataURI;
  }

  function setWithdrawDelay(uint24 _withdrawDelay) public override onlyOwner onlyBeforeSale {
    setWithdrawTime(endTime + _withdrawDelay);
    super.setWithdrawDelay(_withdrawDelay);
  }

  function setLinearVestingEndTime(uint256 _vestingEndTime) public override onlyOwner onlyBeforeSale {
    super.setLinearVestingEndTime(_vestingEndTime);
  }

  function setCliffPeriod(uint256[] calldata claimTimes, uint8[] calldata pct) public override onlyOwner onlyBeforeSale {
    super.setCliffPeriod(claimTimes, pct);
  }

  function purchase(uint256 paymentAmount) public virtual override onlyDuringSale {
    require(whitelistRootHash == 0, "use whitelisted purchase");

    uint256 remaining = maxTotalPayment.sub(paymentReceived[_msgSender()]);
    _purchase(paymentAmount, remaining);
  }

  function whitelistedPurchase(uint256 paymentAmount, bytes32[] calldata merkleProof) public virtual override onlyDuringSale {
    require(checkWhitelist(_msgSender(), merkleProof), "proof invalid");
    _purchase(paymentAmount, maxTotalPayment);
  }

  function withdraw() public virtual override onlyAfterSale nonReentrant {
    address user = _msgSender();
    require(salePrice > 0, "use withdraw giveaway");

    uint256 tokenOwed = getCurrentClaimableToken(user);
    _withdraw(tokenOwed);
    require(tokenOwed != 0, "no token to be withdrawn");
  }

  function emergencyWithdraw() public nonReentrant {
    address user = _msgSender();
    require(!hasCashed, "sale has been cashed already");
    require(!hasWithdrawn[user], "cannot use emergency withdrawal after regular withdrawal");
    require(paymentReceived[user] > 0, "you did not contribute to this sale");
    TransferHelpers._safeTransferERC20(address(paymentToken), user, paymentReceived[user]);

    totalPaymentReceived -= paymentReceived[user];

    purchaserCount -= 1;
    paymentReceived[user] = 0;
    totalPurchased[user] = 0;
    claimable[user] = 0;

    emit EmergencyWithdrawal(user);
  }

  function withdrawGiveaway(bytes32[] calldata merkleProof) public virtual override onlyAfterSale nonReentrant {
    address user = _msgSender();
    require(salePrice == 0, "not a giveaway");
    require(whitelistRootHash == 0 || checkWhitelist(user, merkleProof), "proof invalid");

    uint256 tokenOwed = getCurrentClaimableToken(user);
    if (!hasWithdrawn[user]) {
      claimable[user] = tokenOwed;
      totalPurchased[user] = tokenOwed;
    }
    _withdraw(tokenOwed);
    require(tokenOwed > 0, "withdraw giveaway amount low");
  }

  function _purchase(uint256 paymentAmount, uint256 remaining) internal override {
    uint256 saleTokensSold = getSaleTokensSold();
    uint256 space = saleAmount > saleTokensSold ? saleAmount.sub(saleTokensSold) : saleTokensSold.sub(saleAmount);
    require(space > 0, "all tokens sold");
    uint256 saleTokenAmount = (paymentAmount * SALE_PRICE_DECIMALS) / salePrice;
    uint256 pAmount = space >= saleTokenAmount ? paymentAmount : (space * salePrice) / SALE_PRICE_DECIMALS;
    totalPaymentReceived += pAmount;
    super._purchase(pAmount, remaining);

    uint256 tokenPurchased = (paymentReceived[_msgSender()] * SALE_PRICE_DECIMALS) / salePrice;
    totalPurchased[_msgSender()] = tokenPurchased;
    claimable[_msgSender()] = tokenPurchased;
  }

  function _withdraw(uint256 tokenOwed) internal override {
    super._withdraw(tokenOwed);
    latestClaimTime[_msgSender()] = block.timestamp;
    claimable[_msgSender()] -= tokenOwed;
  }

  function getSaleTokensSold() internal view override returns (uint256 amount) {
    return (totalPaymentReceived * SALE_PRICE_DECIMALS) / salePrice;
  }

  function getCurrentClaimableToken(address user) public view returns (uint256) {
    return getUnlockedToken(totalPurchased[user], claimable[user], user);
  }

  function checkWhitelist(address user, bytes32[] calldata merkleProof) public view virtual returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(user));
    return MerkleProof.verify(merkleProof, whitelistRootHash, leaf);
  }

  function setMetadataURI(string memory _metadataURI) external onlyOwner {
    metadataURI = _metadataURI;
    emit MetadataURIChanged(_metadataURI);
  }
}
