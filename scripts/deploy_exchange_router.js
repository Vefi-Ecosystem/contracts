const { ethers, network } = require("hardhat");
const path = require("path");
const fs = require("fs");

(async () => {
  const routerFactory = await ethers.getContractFactory("SparkfiRouter");
  let router = await routerFactory.deploy([], "0x1C7678A4A9AFD8cADe4EFf20e5C881c7496870Df", "0x4200000000000000000000000000000000000006", [
    "0x4200000000000000000000000000000000000006",
    "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA",
    "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb",
    "0xEB466342C4d449BC9f53A865D5Cb90586f405215",
    "0x4b9C9B4e39d4e5026359b05a6287Ee4d0737f211",
    "0xc2BC7A73613B9bD5F373FE10B55C59a69F4D617B",
    "0x3055913c90Fcc1A6CE9a358911721eEb942013A1",
    "0xb79dd08ea68a908a97220c76d19a6aa9cbde4376"
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

  console.log(router.address);
})();
