const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const xChangeRouter = await ethers.getContractFactory("FabulousExchangeMultiHopsRouter");
  let fctry = await xChangeRouter.deploy("0x143873126b7f77a1c8bE3481e77e9cAD402EE538");
  fctry = await fctry.deployed();

  const location = path.join(__dirname, "../multihops_routers.json");
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
