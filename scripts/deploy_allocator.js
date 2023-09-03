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
  let allocator = await allocatorFactory.deploy("0x1C7678A4A9AFD8cADe4EFf20e5C881c7496870Df", "0x64FAF984Bf60dE19e24238521814cA98574E3b00", 150340);
  allocator = await allocator.deployed();

  const contentBuf = fs.readFileSync(location);
  const contentJSON = JSON.parse(contentBuf.toString());

  let arr = contentJSON[network.config.chainId];

  if (!arr) arr = [];

  arr.push(allocator.address);

  fs.writeFileSync(location, JSON.stringify({ ...contentJSON, [network.config.chainId]: arr }, undefined, 2));

  console.log("Allocator: ", allocator.address);
})();
