const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const location = path.join(__dirname, "../exchange_adapters.json");
  const fileExists = fs.existsSync(location);

  if (!fileExists) return;
  const adapterFactory = await ethers.getContractFactory("PancakeswapAdapter");
  let adapter = await adapterFactory.deploy("Pancakeswap V2", "0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB", 25, 215000);
  adapter = await adapter.deployed();

  const contentBuf = fs.readFileSync(location);
  const contentJSON = JSON.parse(contentBuf.toString());

  let arr = contentJSON[network.config.chainId];

  if (!arr) arr = [];

  arr.push(adapter.address);

  fs.writeFileSync(location, JSON.stringify({ ...contentJSON, [network.config.chainId]: arr }, undefined, 2));
})();
