const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const routerFactory = await ethers.getContractFactory("SparkfiRouter");
  let router = await routerFactory.deploy([], "0xb69DB7b7B3aD64d53126DCD1f4D5fBDaea4fF578", "0x4200000000000000000000000000000000000006", [
    "0x4200000000000000000000000000000000000006",
    "0x2e9F75DF8839ff192Da27e977CD154FD1EAE03cf",
    "0x6D0F8D488B669aa9BA2D0f0b7B75a88bf5051CD3",
    "0xB37A5498A6386b253FC30863A41175C3f9c0723B",
    "0x6440c59d7c7c108d3Bb90E4bDeeE8262c975858a"
  ]);
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
