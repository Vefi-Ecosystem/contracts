const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const USDBFactory = await ethers.getContractFactory("USDB");
  let usdb = await USDBFactory.deploy("USDB", "USDB", ethers.utils.parseUnits("10000000000", 18), "0x8754e02Aab325BA8350257F48b9F91d7CeF80bA3", 8);
  usdb = await usdb.deployed();

  const location = path.join(__dirname, "../usdb_addresses.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: usdb.address
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: usdb.address
        },
        undefined,
        2
      )
    );
  }
})();
