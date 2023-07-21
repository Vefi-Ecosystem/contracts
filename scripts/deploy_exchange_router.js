const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const routerFactory = await ethers.getContractFactory("SparkfiRouter");
  let router = await routerFactory.deploy([], "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578", "0x4200000000000000000000000000000000000006");
  router = await router.deployed();

  const location = path.join(__dirname, "../exchange_routers.json");
  const fileExists = fs.existsSync(location);

  if (fileExists) {
    const contentBuf = fs.readFileSync(location);
    let contentJSON = JSON.parse(contentBuf.toString());
    contentJSON = {
      ...contentJSON,
      [network.config.chainId]: router.address
    };
    fs.writeFileSync(location, JSON.stringify(contentJSON, undefined, 2));
  } else {
    fs.writeFileSync(
      location,
      JSON.stringify(
        {
          [network.config.chainId]: router.address
        },
        undefined,
        2
      )
    );
  }
})();
