const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");
const { abi: routerABI } = require("../artifacts/contracts/swap_aggregator/SparkfiRouter.sol/SparkfiRouter.json");

require("dotenv").config();

(async () => {
  const location = path.join(__dirname, "../exchange_adapters.json");
  const fileExists = fs.existsSync(location);

  if (!fileExists) return;

  const adapterFactory = await ethers.getContractFactory("DackieSwapAdapter");
  let adapter = await adapterFactory.deploy("DackieSwap", "0x1D25b9D81623a093ffc2b02E8da1d006b16F0AD8", 3);
  adapter = await adapter.deployed();

  const contentBuf = fs.readFileSync(location);
  const contentJSON = JSON.parse(contentBuf.toString());

  let arr = contentJSON[network.config.chainId];

  if (!arr) arr = [];

  arr[arr.length >= 1 ? 1 : arr.length - 1] = adapter.address;

  fs.writeFileSync(location, JSON.stringify({ ...contentJSON, [network.config.chainId]: arr }, undefined, 2));

  const routersLocation = path.join(__dirname, "../exchange_routers.json");
  const routerContentBuf = fs.readFileSync(routersLocation);
  const routerContentJSON = JSON.parse(routerContentBuf.toString());

  const router = routerContentJSON[network.config.chainId];
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
  const tx = await new ethers.Contract(router, routerABI).connect(wallet).setAdapters(arr);
  await tx.wait();
})();
