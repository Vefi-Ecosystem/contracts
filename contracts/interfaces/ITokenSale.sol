pragma solidity ^0.8.0;

interface ITokenSale {
  enum SaleType {
    PUBLIC_REGULAR,
    PUBLIC_VESTABLE,
    PRIVATE_REGULAR,
    PRIVATE_VESTABLE
  }

  function token() external view returns (address);

  function tokensAvailableForSale() external view returns (uint256);

  function tokensPerEther() external view returns (uint256);

  function saleCreator() external view returns (address);

  function hardcap() external view returns (uint256);

  function softcap() external view returns (uint256);

  function proceedsTo() external view returns (address);

  function saleCreatorPercentage() external view returns (uint8);

  function saleStartTime() external view returns (uint256);

  function saleEndTime() external view returns (uint256);

  function admin() external view returns (address);

  function isSaleEnded() external view returns (bool);

  function isBanned(address account) external view returns (bool);

  function balances(address account) external view returns (uint256);

  function minContribution() external view returns (uint256);

  function maxContribution() external view returns (uint256);

  function amountContributed(address account) external view returns (uint256);

  function contribute() external payable;

  function emergencyWithdraw() external;

  function finalizeSale() external;

  function saleType() external view returns (SaleType);
}
