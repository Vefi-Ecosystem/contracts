const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const location = path.join(__dirname, "../exchange_adapters.json");
  const fileExists = fs.existsSync(location);

  if (!fileExists) return;
  const adapterFactory = await ethers.getContractFactory("AerodromeAdapter");
  let adapter = await adapterFactory.deploy("Aerodrome", "0x420DD381b31aEf6683db6B902084cB0FFECe40Da", 215000);
  adapter = await adapter.deployed();

  const contentBuf = fs.readFileSync(location);
  const contentJSON = JSON.parse(contentBuf.toString());

  let arr = contentJSON[network.config.chainId];

  if (!arr) arr = [];

  arr.push(adapter.address);

  fs.writeFileSync(location, JSON.stringify({ ...contentJSON, [network.config.chainId]: arr }, undefined, 2));
})();
