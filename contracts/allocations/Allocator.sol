pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IAllocator.sol";
import "../helpers/TransferHelper.sol";
import "./Lottery.sol";

contract Allocator is Ownable, AccessControl, Pausable, ReentrancyGuard, IAllocator {
  using SafeMath for uint256;
  using Address for address;

  struct StakeInfo {
    uint256 timestamp;
    uint256 amountStaked;
  }

  struct Tier {
    string name;
    uint256 num;
  }

  bytes32 public penaltyClause = keccak256(abi.encodePacked("penaltyForEarlyWithdrawal"));

  mapping(bytes32 => uint16) public earlyUnstakePenalties;
  mapping(address => StakeInfo[]) public userStakes;
  mapping(address => Tier) public userTier;

  address public immutable token;
  Tier[] public tiers;

  uint24 public apr;
  uint256 public totalStaked;

  address public lottery;

  constructor(
    address newOwner,
    ERC20 _token,
    uint16 _apr
  ) {
    require(newOwner != address(0), "cannot be zero address");
    require(address(_token).isContract(), "must be contract");

    token = address(_token);
    apr = _apr;
    _initEarlyUnstakePenalties();
    _initTiers();
    _transferOwnership(newOwner);
  }

  function _encodeRange(uint256 _day) private view returns (bytes32 enc) {
    bytes32 dayEnc = keccak256(abi.encodePacked(_day, penaltyClause));
    enc = keccak256(abi.encodePacked(dayEnc, penaltyClause));
  }

  function _initEarlyUnstakePenalties() private {
    addEarlyUnstakingPenaltiesForRange(0, 10, 10);
    addEarlyUnstakingPenaltiesForRange(11, 9, 5);
    addEarlyUnstakingPenaltiesForRange(21, 9, 3);
  }

  function _initTiers() private {
    addTier("Luna", 100000e18);
    addTier("Selene", 200000e18);
    addTier("Artemis", 400000e18);
    addTier("Diana", 800000e18);
  }

  function addTier(string memory name, uint256 num) public onlyOwner {
    Tier memory tier = Tier({name: name, num: num});
    tiers.push(tier);
    emit TierAdded(name, num);
  }

  function getUnstakeableByAccount(address _account) public view returns (uint256) {
    uint256 _r = accountReward(_account);
    uint256 _totalAndReward = userWeight(_account).mul(_r);
    StakeInfo[] memory stakeInfos = userStakes[_account];

    uint256 t = block.timestamp;
    uint256 _penaltyFee;

    for (uint256 i = 0; i < stakeInfos.length; i++) {
      uint256 elapsed = t.sub(stakeInfos[i].timestamp);
      uint256 elapsedInDays = elapsed.div(86400) * 1 days;
      bytes32 enc = _encodeRange(elapsedInDays);
      _penaltyFee += (earlyUnstakePenalties[enc] * stakeInfos[i].amountStaked) / 100;
    }
    return _totalAndReward.sub(_penaltyFee);
  }

  function accountReward(address _account) public view returns (uint256) {
    StakeInfo[] memory stakeInfos = userStakes[_account];
    uint256 accumulatedReward;
    uint256 timestamp = block.timestamp;

    for (uint256 i = 0; i < stakeInfos.length; i++) {
      uint256 t = timestamp.sub(stakeInfos[i].timestamp);
      uint256 x = 1 + (((apr * t) / 100) / 31536000);
      accumulatedReward += x;
    }
    return accumulatedReward;
  }

  function userWeight(address _account) public view returns (uint256 accountStake) {
    StakeInfo[] memory stakeInfos = userStakes[_account];

    for (uint256 i = 0; i < stakeInfos.length; i++) accountStake += stakeInfos[i].amountStaked;
  }

  function addEarlyUnstakingPenaltiesForRange(
    uint16 _start,
    uint16 _gap,
    uint16 _percentage
  ) public onlyOwner {
    uint256 rangeMax = uint256(_start).add(uint256(_gap));

    for (uint256 i = uint256(_start); i <= rangeMax; i++) {
      uint256 day = i.mul(1 days);
      bytes32 encodedR = _encodeRange(day);
      earlyUnstakePenalties[encodedR] = _percentage;
    }
  }

  function _stake(address account, uint256 amount) private {
    StakeInfo[] memory stakeInfos = userStakes[account];

    TransferHelpers._safeTransferFromERC20(token, _msgSender(), address(this), amount);

    StakeInfo memory stakeInfo = StakeInfo({timestamp: block.timestamp, amountStaked: amount});
    totalStaked = totalStaked.add(amount);

    if (stakeInfos.length > 0) {
      stakeInfos[stakeInfos.length - 1] = stakeInfo;
    } else {
      stakeInfos[0] = stakeInfo;
    }

    userStakes[_msgSender()] = stakeInfos;

    uint256 totalStakes = userWeight(account);

    for (uint256 i = 0; i < tiers.length; i++) {
      if (totalStakes >= tiers[i].num) {
        userTier[account] = tiers[i];
      }
    }

    emit Stake(_msgSender(), amount, stakeInfo.timestamp);
  }

  function stake(uint256 amount) external whenNotPaused {
    require(IERC20(token).allowance(_msgSender(), address(this)) >= amount, "not enough allowance");
    _stake(_msgSender(), amount);
  }

  function unstake() external {
    uint256 tsa = userWeight(_msgSender());
    uint256 unstakeable = getUnstakeableByAccount(_msgSender());
    TransferHelpers._safeTransferERC20(token, _msgSender(), unstakeable);
    delete userStakes[_msgSender()];

    totalStaked = totalStaked.sub(tsa);
    emit Unstake(_msgSender(), tsa);
  }

  function retrieveEther(address to) external onlyOwner {
    uint256 amount = address(this).balance;
    TransferHelpers._safeTransferEther(to, amount);
  }

  function retrieveExcessStakeToken(address to) external onlyOwner {
    uint256 amount = IERC20(token).balanceOf(address(this)).sub(totalStaked);
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function retrieveERC20(address _token, address to) external onlyOwner {
    require(_token != token, "use retrieveExcessStakeToken");
    uint256 amount = IERC20(_token).balanceOf(address(this));
    TransferHelpers._safeTransferERC20(_token, to, amount);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function setAPR(uint24 _apr) external onlyOwner {
    apr = _apr;
  }

  function createLottery(uint16 percentage) external onlyOwner {
    require(lottery == address(0), "lottery already initialized");
    bytes memory creationCode = type(Lottery).creationCode;
    bytes memory constructorArgs = abi.encode(
      "Sparkfi Lottery Pool",
      string.concat("SLP-", string(abi.encode(uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, address(this)))) % 1e4))),
      token,
      owner(),
      address(this)
    );
    bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
    bytes32 salt = keccak256(abi.encodePacked(address(this), block.prevrandao, block.timestamp));
    address ltry;

    assembly {
      ltry := create2(0, add(bytecode, 32), mload(bytecode), salt)

      if iszero(extcodesize(ltry)) {
        revert(0, "could not deploy sale contract")
      }
    }

    lottery = ltry;

    uint256 balance = IERC20(token).balanceOf(address(this));
    uint256 x = balance > totalStaked ? balance : totalStaked;
    uint256 communityPoolAllocation = (percentage * x) / 100;

    TransferHelpers._safeTransferERC20(token, ltry, communityPoolAllocation);
  }

  function addLotteryParticipants(
    address[] memory accounts,
    uint256[] memory nums,
    string memory _tokenURI
  ) external onlyOwner {
    require(lottery != address(0), "no lottery");
    Lottery(lottery).mintTickets(nums, accounts, _tokenURI);
  }

  function endLottery() external onlyOwner {
    require(lottery != address(0), "no lottery");
    Lottery l = Lottery(lottery);
    l.selectWinners();
    address[] memory winners = l.getWinners();
    uint256 bal = IERC20(token).balanceOf(lottery);
    l.retrieveTokens(address(this), bal);

    if (winners.length > 0) {
      uint256 factor = bal / winners.length;
      for (uint256 i = 0; i < winners.length; i++) {
        _stake(winners[i], factor);
      }
    }

    lottery = address(0);
  }

  receive() external payable {}
}
