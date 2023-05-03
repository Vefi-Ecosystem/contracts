const { expect, use } = require("chai");
const { ethers, waffle } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");

use(waffle.solidity);

describe("Tests", () => {
  describe("Presale", () => {
    /**
     * @type {import('ethers').Contract}
     */
    let presale;

    /**
     * @type {import('ethers').Contract}
     */
    let erc201;

    /**
     * @type {import('ethers').Contract}
     */
    let erc202;

    before(async () => {
      const PresaleContractFactory = await ethers.getContractFactory("Presale");
      const ERC20Factory = await ethers.getContractFactory("TestERC20");
      const [signer1] = await ethers.getSigners();

      erc201 = await ERC20Factory.deploy(ethers.utils.parseEther("4000"));
      erc201 = await erc201.deployed();

      erc202 = await ERC20Factory.deploy(ethers.utils.parseEther("8000"));
      erc202 = await erc202.deployed();

      presale = await PresaleContractFactory.deploy(
        "https://google.com",
        signer1.address,
        ethers.utils.parseEther("1000"),
        erc201.address,
        erc202.address,
        Math.floor(Date.now() / 1000) + 3600,
        Math.floor(Date.now() / 1000) + 3600 * 24,
        ethers.utils.parseEther("7000")
      );
      presale = await presale.deployed();
    });

    it("should allow only funder", async () => {
      const [, signer2] = await ethers.getSigners();
      await erc202.connect(signer2).approve(presale.address, ethers.utils.parseEther("7000").toHexString());
      await expect(presale.connect(signer2).fund(ethers.utils.parseEther("7000").toHexString())).to.be.reverted;
    });

    it("should allow funding by funder", async () => {
      await erc202.approve(presale.address, ethers.utils.parseEther("7000").toHexString());
      await expect(presale.fund(ethers.utils.parseEther("7000").toHexString())).to.emit(presale, "Fund");
    });
  });
});
