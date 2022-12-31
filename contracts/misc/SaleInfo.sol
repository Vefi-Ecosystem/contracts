pragma solidity ^0.8.0;

struct PresaleInfo {
  address token;
  uint256 tokensForSale;
  uint256 softcap;
  uint256 hardcap;
  uint256 tokensPerEther;
  uint256 minContributionEther;
  uint256 maxContributionEther;
  uint256 saleStartTime;
  uint256 daysToLast;
  address proceedsTo;
  address admin;
}

struct PrivateSaleInfo {
  address token;
  uint256 tokensForSale;
  uint256 softcap;
  uint256 hardcap;
  uint256 tokensPerEther;
  uint256 minContributionEther;
  uint256 maxContributionEther;
  uint256 saleStartTime;
  uint256 daysToLast;
  address proceedsTo;
  address admin;
  address[] whitelist;
}
