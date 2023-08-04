pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../helpers/TransferHelper.sol";

contract Lottery is Ownable, AccessControl, ERC721URIStorage {
  using Counters for Counters.Counter;
  address[] public participants;
  address[] public winners;

  Counters.Counter tokenIds;

  ERC20 token;
  bytes32 public whitelistRootHash;
  bytes32 public managerRole = keccak256(abi.encodePacked("MANAGER_ROLE"));

  constructor(
    string memory _name,
    string memory _symbol,
    ERC20 _token,
    address _manager,
    address newOwner
  ) ERC721(_name, _symbol) {
    token = _token;
    _grantRole(managerRole, _msgSender());
    _grantRole(managerRole, _manager);
    _transferOwnership(newOwner);
  }

  modifier onlyManagerOrOwner() {
    require(hasRole(managerRole, _msgSender()) || owner() == _msgSender(), "only manager or owner");
    _;
  }

  function random(uint256 num) private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, num)));
  }

  function mintTickets(
    uint256[] memory nums,
    address[] memory accounts,
    string memory _tokenURI
  ) external onlyManagerOrOwner {
    require(nums.length == accounts.length, "arrays must be same length");

    for (uint256 i = 0; i < accounts.length; i++) {
      for (uint256 j = 0; j < nums[i]; j++) {
        tokenIds.increment();

        uint256 tokenId = tokenIds.current();
        _mint(accounts[i], tokenId);
        _setTokenURI(tokenId, _tokenURI);
        participants.push(accounts[i]);
      }
    }
  }

  function selectWinners() external onlyManagerOrOwner {
    uint256 _startIndex = random(participants.length) % participants.length;
    uint256 steps = 0;

    while (steps == 0) {
      steps = random(10) % 10;
    }

    address[] memory selectedParticipants;

    for (uint256 i = _startIndex; i <= _startIndex + steps; i++) {
      if (participants[i] != address(0)) selectedParticipants[i] = participants[i];
    }

    uint256 requiredBalance = 1;

    for (uint256 i = 0; i < selectedParticipants.length; i++) {
      if (balanceOf(selectedParticipants[i]) >= requiredBalance) {
        winners.push(selectedParticipants[i]);
        requiredBalance = balanceOf(selectedParticipants[i]);
      }
    }
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
    return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId || super.supportsInterface(interfaceId);
  }

  function getWinners() external view returns (address[] memory) {
    return winners;
  }

  function retrieveTokens(address to, uint256 amount) external onlyManagerOrOwner {
    TransferHelpers._safeTransferERC20(address(token), to, amount);
  }
}
