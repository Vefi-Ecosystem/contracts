const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const TokenSaleCreatorFactory = await ethers.getContractFactory("TokenSaleCreator");
  const PrivateTokenSaleCreatorFactory = await ethers.getContractFactory("PrivateTokenSaleCreator");
  let tokenSaleCreator = await TokenSaleCreatorFactory.deploy(5);
  let privateTokenSaleCreator = await PrivateTokenSaleCreatorFactory.deploy(5);
  tokenSaleCreator = await tokenSaleCreator.deployed();
  privateTokenSaleCreator = await privateTokenSaleCreator.deployed();

  const location = path.join(__dirname, "../token_sale_creators_addresses.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: {
        tokenSale: tokenSaleCreator.address,
        privateTokenSale: privateTokenSaleCreator.address
      }
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: {
            tokenSale: tokenSaleCreator.address,
            privateTokenSale: privateTokenSaleCreator.address
          }
        },
        undefined,
        2
      )
    );
  }
})();
