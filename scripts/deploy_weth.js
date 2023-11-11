const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const wethFactory = await ethers.getContractFactory("WETH");
  let fctry = await wethFactory.deploy("Wrapped Vinu", "WVC");
  fctry = await fctry.deployed();

  const location = path.join(__dirname, "../weths.json");
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
