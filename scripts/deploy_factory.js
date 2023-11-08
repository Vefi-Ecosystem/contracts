const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const exchangeFactory = await ethers.getContractFactory("FabulousFactory");
  let fctry = await exchangeFactory.deploy();
  fctry = await fctry.deployed();

  const location = path.join(__dirname, "../exchange_factories.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: fctry.address
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: fctry.address
        },
        undefined,
        2
      )
    );
  }
})();
