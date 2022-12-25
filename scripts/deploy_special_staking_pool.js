const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

const usdbAddresses = {
  32520: "0xc2a9e1dE895a2f8D9F82E67F46ea2cD1BE1f2087"
};

(async () => {
  try {
    console.log("---------- Deploying to chain %d ----------", network.config.chainId);

    const SpecialStakingPoolFactory = await ethers.getContractFactory("SpecialStakingPool");
    let specialStakingPool = await SpecialStakingPoolFactory.deploy(
      "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578",
      "0x927eFa8c553bC6bc7a4c65719Fa415fD3d17E6cE",
      usdbAddresses[network.config.chainId],
      8,
      2400,
      4,
      `0x${(60 * 60 * 24 * 30).toString(16)}`
    );
    specialStakingPool = await specialStakingPool.deployed();

    const location = path.join(__dirname, "../special_staking_pool_addresses.json");
    const fileExists = fs.existsSync(location);

    if (fileExists) {
      const contentBuf = fs.readFileSync(location);
      let contentJSON = JSON.parse(contentBuf.toString());
      contentJSON = {
        ...contentJSON,
        [network.config.chainId]: [...contentJSON[network.config.chainId], specialStakingPool.address]
      };
      fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
    } else {
      fs.writeFileSync(
        location,
        JSON.stringify(
          {
            [network.config.chainId]: [specialStakingPool.address]
          },
          undefined,
          2
        )
      );
    }
  } catch (error) {
    console.log(error);
  }
})();
