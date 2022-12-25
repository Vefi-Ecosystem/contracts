const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");
const axios = require("axios");

const coinGeckID = {
  97: "binancecoin",
  56: "binancecoin",
  32520: "bitrise-token",
  311: "omax-token",
  86: "gatechain-token",
  888: "wanchain",
  66: "oec-token",
  1: "ethereum"
};

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const TokenSaleCreatorFactory = await ethers.getContractFactory("TokenSaleCreator");
  const PrivateTokenSaleCreatorFactory = await ethers.getContractFactory("PrivateTokenSaleCreator");
  const cgID = coinGeckID[network.config.chainId];
  const { data } = await axios.get(`https://api.coingecko.com/api/v3/simple/price?ids=${cgID}&vs_currencies=usd`);
  const valInUSD = data[cgID].usd;
  const valEther = 200 / valInUSD;
  let tokenSaleCreator = await TokenSaleCreatorFactory.deploy(5, ethers.utils.parseEther(valEther.toString()));
  let privateTokenSaleCreator = await PrivateTokenSaleCreatorFactory.deploy(5, ethers.utils.parseEther(valEther.toString()));
  tokenSaleCreator = await tokenSaleCreator.deployed();
  console.log("TokenSaleCreator ", tokenSaleCreator.address);
  privateTokenSaleCreator = await privateTokenSaleCreator.deployed();
  console.log("PrivateTokenSaleCreator ", privateTokenSaleCreator.address);

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
