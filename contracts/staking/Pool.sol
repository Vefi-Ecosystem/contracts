pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../helpers/TransferHelper.sol";

contract Pool is Ownable, AccessControl, ReentrancyGuard {
  IERC20 public immutable stakeToken;
  IERC20 public immutable rewardToken;

  uint256 public rewardByBlock;
  uint256 public rewardsUnlockBlock;
  uint256 public immutable startBlock;
  uint256 public immutable endBlock;
  uint256 public REWARD_DENOMINATOR = 1e5;
  uint256 public totalRewardsAvailable;
  uint256 public totalStaked;

  uint16 public stakeTax;
  uint16 public unstakeTax;

  bytes32 public MOD_ROLE = keccak256(abi.encodePacked("MOD_ROLE"));

  mapping(address => uint256) public amountStaked;
  mapping(address => uint256[]) public stakeBlocks;
  mapping(address => bool) public blocked;

  address taxReceiver;
  address public immutable deployer;

  modifier mustBeMod() {
    require(hasRole(MOD_ROLE, _msgSender()), "must be moderator");
    _;
  }

  modifier onlyNonBlockedAccounts() {
    require(!blocked[_msgSender()], "only non-blocked accounts");
    _;
  }

  modifier mustBeWithinBlocks() {
    require(block.number >= startBlock, "not started");
    require(block.number < endBlock, "already ended");
    _;
  }

  modifier ownerOrDeployer() {
    require(_msgSender() == owner() || _msgSender() == deployer, "must be owner or deployer");
    _;
  }

  event Stake(address indexed staker, uint256 indexed amount, uint256 indexed timestamp);
  event Unstake(address indexed staker, uint256 indexed amount, uint256 indexed timestamp);

  constructor(
    IERC20 _stakeToken,
    IERC20 _rewardToken,
    uint256 _rewardByBlock,
    uint256 _rewardsUnlockBlock,
    uint256 _startBlock,
    uint256 _endBlock,
    uint16 _stakeTax,
    uint16 _unstakeTax,
    address newOwner,
    address _taxReceiver
  ) Ownable() {
    require(_endBlock >= _startBlock + 1e12, "start block and end block must be at least 1000000000000 blocks apart");

    stakeToken = _stakeToken;
    rewardToken = _rewardToken;
    rewardByBlock = _rewardByBlock;
    rewardsUnlockBlock = _rewardsUnlockBlock;
    startBlock = _startBlock;
    endBlock = _endBlock;
    stakeTax = _stakeTax;
    unstakeTax = _unstakeTax;
    taxReceiver = _taxReceiver;

    _transferOwnership(newOwner);
    _grantRole(MOD_ROLE, newOwner);

    deployer = _msgSender();
  }

  function getPerBlockRewards(address staker) public view returns (uint256) {
    uint256 totalReward;
    uint256[] memory blocks = stakeBlocks[staker];

    if (block.number < rewardsUnlockBlock) return 0;
    if (blocks.length == 0) return 0;

    for (uint256 i = 0; i < blocks.length; i++) {
      uint256 reward = (block.number - blocks[i]) * rewardByBlock;
      totalReward += reward;
    }

    return totalReward;
  }

  function stake(uint256 amount) external onlyNonBlockedAccounts mustBeWithinBlocks nonReentrant {
    uint256 tax = (stakeTax / 100) * amount;
    uint256 stakeAmount = amount - tax;

    TransferHelpers._safeTransferFromERC20(address(stakeToken), _msgSender(), address(this), stakeAmount);
    amountStaked[_msgSender()] += stakeAmount;

    if (tax > 0) {
      TransferHelpers._safeTransferERC20(address(stakeToken), taxReceiver, tax);
    }

    stakeBlocks[_msgSender()].push(block.number);

    totalStaked += stakeAmount;

    emit Stake(_msgSender(), amount, block.timestamp);
  }

  function unstake(uint256 amount) external nonReentrant {
    require(amountStaked[_msgSender()] >= amount, "stake amount is less");
    uint256 tax = (unstakeTax / 100) * amount;
    uint256 unstakeAmount = amount - tax;

    TransferHelpers._safeTransferERC20(address(stakeToken), _msgSender(), unstakeAmount);
    amountStaked[_msgSender()] -= amount;

    if (tax > 0) {
      TransferHelpers._safeTransferERC20(address(stakeToken), taxReceiver, tax);
    }

    if (amountStaked[_msgSender()] == 0) {
      delete stakeBlocks[_msgSender()];
    }

    totalStaked -= amount;

    emit Unstake(_msgSender(), amount, block.timestamp);
  }

  function withdrawReward() external nonReentrant mustBeWithinBlocks {
    uint256 amount = amountStaked[_msgSender()];
    require(amount > 0, "did not stake");
    uint256 reward = ((getPerBlockRewards(_msgSender()) / REWARD_DENOMINATOR) + (amount / REWARD_DENOMINATOR)) / (endBlock - block.number);
    TransferHelpers._safeTransferERC20(address(rewardToken), _msgSender(), reward);
    totalRewardsAvailable -= reward;
  }

  function fundPool(uint256 amount) external ownerOrDeployer mustBeWithinBlocks {
    require(amount > 0, "must be greater than 0");
    TransferHelpers._safeTransferFromERC20(address(rewardToken), _msgSender(), address(this), amount);
    totalRewardsAvailable += amount;
  }

  function defundPool(address to) external onlyOwner {
    require(totalRewardsAvailable > 0, "fund is 0");
    require(block.number >= endBlock, "cannot defund pool now");
    TransferHelpers._safeTransferERC20(address(rewardToken), to, totalRewardsAvailable);
    totalRewardsAvailable = 0;
  }

  function getRetrievableRewardToken() public view returns (uint256 retrievable) {
    uint256 balance = rewardToken.balanceOf(address(this));
    retrievable = balance - totalRewardsAvailable;
  }

  function getRetrievableStakeToken() public view returns (uint256 retrievable) {
    uint256 balance = stakeToken.balanceOf(address(this));
    retrievable = balance - totalStaked;
  }

  function retrieveTokens(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    if (token == address(rewardToken)) {
      uint256 retrievable = getRetrievableRewardToken();
      require(amount <= retrievable, "amount must be less than or equal to retrievable amount for reward token");
    }

    if (token == address(stakeToken)) {
      uint256 retrievable = getRetrievableStakeToken();
      require(amount <= retrievable, "amount must be less than or equal to retrievable amount for stake token");
    }

    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function switchBlockStatusForAddress(address account) external mustBeMod {
    blocked[account] = !blocked[account];
  }

  function setBlockForRewardDistribution(uint256 blk) external mustBeMod {
    rewardsUnlockBlock = blk;
  }

  function setStakeTax(uint16 _stakeTax) external mustBeMod {
    stakeTax = _stakeTax;
  }

  function setUnstakeTax(uint16 _unstakeTax) external mustBeMod {
    unstakeTax = _unstakeTax;
  }

  function setRewardByBlock(uint256 _rewardByBlock) external mustBeMod {
    rewardByBlock = _rewardByBlock;
  }
}
