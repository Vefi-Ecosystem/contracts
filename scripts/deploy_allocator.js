const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const location = path.join(__dirname, "../allocators.json");
  const fileExists = fs.existsSync(location);

  if (!fileExists) {
    fs.writeFileSync(location, JSON.stringify({}));
  }

  const allocatorFactory = await ethers.getContractFactory("Allocator");
  let allocator = await allocatorFactory.deploy("0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578", "0x1c6a839b617ecF785A6aD702B1FAACcD5e4ccaaC", 150340);
  allocator = await allocator.deployed();

  const contentBuf = fs.readFileSync(location);
  const contentJSON = JSON.parse(contentBuf.toString());

  let arr = contentJSON[network.config.chainId];

  if (!arr) arr = [];

  arr.push(allocator.address);

  fs.writeFileSync(location, JSON.stringify({ ...contentJSON, [network.config.chainId]: arr }, undefined, 2));

  console.log("Allocator: ", allocator.address);
})();
