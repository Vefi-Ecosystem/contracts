pragma solidity ^0.8.0;

import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is IWETH, ERC20 {
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

  receive() external payable {
    deposit();
  }

  function deposit() public payable {
    assert(msg.value > 0);
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint256 value) external {
    uint256 balance = balanceOf(msg.sender);
    require(balance >= value, "insufficient balance");
    (bool success, ) = msg.sender.call{value: value}(new bytes(0));
    require(success, "could not withdraw");
    _burn(msg.sender, value);
  }
}
