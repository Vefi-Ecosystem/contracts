pragma solidity ^0.8.0;

import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakePair.sol";

contract FabulousExchangeMultiHopsRouter {
  IPancakeFactory public factory;
  IPancakeRouter02 public router;

  constructor(IPancakeFactory _factory, IPancakeRouter02 _router) {
    factory = _factory;
    router = _router;
  }

  function _getAllPossiblePaths(address tokenA, address tokenB) private view returns (address[] memory) {
    address firstPair = factory.getPair(tokenA, tokenB);
    address[] memory paths;
    uint256 allPairsLength = factory.allPairsLength();

    if (firstPair != address(0)) {
      paths[0] = tokenA;
      paths[1] = tokenB;
      return paths;
    }

    address[] memory allTokenAPartners;

    for (uint256 i = 0; i < allPairsLength; i++) {
      address pairAddress = factory.allPairs(i);
      IPancakePair pair = IPancakePair(pairAddress);

      if (pair.token0() == tokenA || pair.token1() == tokenA) {
        allTokenAPartners[allTokenAPartners.length] = pair.token0() == tokenA ? pair.token1() : pair.token0();
      }
    }

    address tokenAB;

    for (uint256 i = 0; i < allTokenAPartners.length; i++) {
      address pair = factory.getPair(tokenB, allTokenAPartners[i]);

      if (pair != address(0)) {
        tokenAB = allTokenAPartners[i];
        break;
      }
    }

    paths[0] = tokenA;
    paths[1] = tokenAB;
    paths[2] = tokenB;

    return paths;
  }
}
