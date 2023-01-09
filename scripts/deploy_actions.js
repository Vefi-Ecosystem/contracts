const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");
const axios = require("axios");

const coinGeckID = {
  56: "binancecoin",
  32520: "bitrise-token",
  311: "omax-token",
  86: "gatechain-token",
  888: "wanchain",
  66: "oec-token",
  137: "matic-network"
};

(async () => {
  console.log("---------- Deploying to chain %d ----------", network.config.chainId);
  const StakingPoolActionsFactory = await ethers.getContractFactory("StakingPoolActions");
  const cgID = coinGeckID[network.config.chainId];
  const { data } = await axios.get(`https://api.coingecko.com/api/v3/simple/price?ids=${cgID}&vs_currencies=usd`);
  const valInUSD = data[cgID].usd;
  console.log("-----", valInUSD);
  const valEther = 120 / valInUSD;

  let stakingPoolActions = await StakingPoolActionsFactory.deploy(ethers.utils.parseEther(valEther.toString()));
  stakingPoolActions = await stakingPoolActions.deployed();

  const location = path.join(__dirname, "../staking_pool_actions_addresses.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: stakingPoolActions.address
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: stakingPoolActions.address
        },
        undefined,
        2
      )
    );
  }
})();
