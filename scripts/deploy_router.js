const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const xChangeRouter = await ethers.getContractFactory("FabulousExchangeRouter");
  let fctry = await xChangeRouter.deploy("0x4b0F63996593d68Be92367ebeB39467aF652e82F", "0xE074CFd7FD1Ed79A53a9871429aC5240263b5703");
  fctry = await fctry.deployed();

  const location = path.join(__dirname, "../routers.json");
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
