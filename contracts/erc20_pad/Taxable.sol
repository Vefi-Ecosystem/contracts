pragma solidity ^0.8.0;

import "node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "node_modules/@openzeppelin/contracts/utils/Context.sol";

abstract contract Taxable is Context, AccessControl {
  address public taxCollector;
  uint16 public taxPercentage;
  bytes32 public taxSetterRole = keccak256(abi.encodePacked("TAX_SETTER_ROLE"));

  constructor(
    address _taxCollector,
    uint16 _taxPercentage,
    address _taxSetter
  ) {
    taxCollector = _taxCollector;
    taxPercentage = _taxPercentage;
    _grantRole(taxSetterRole, _taxSetter);
  }

  modifier onlyTaxSetter() {
    require(hasRole(taxSetterRole, _msgSender()), "must be tax setter");
    _;
  }

  function setTaxPercentage(uint8 _taxPercentage) external onlyTaxSetter {
    taxPercentage = _taxPercentage;
  }

  function setTaxCollector(address _taxCollector) external onlyTaxSetter {
    taxCollector = _taxCollector;
  }
}
