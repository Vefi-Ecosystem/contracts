const { expect, use } = require("chai");
const { ethers, waffle } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");
const { BigNumber } = require("bignumber.js");

use(waffle.solidity);

describe("Tests", () => {
  describe("Allocator", () => {
    /**
     * @type {import('ethers').Contract}
     */
    let erc20;

    /**
     * @type {import('ethers').Contract}
     */
    let allocator;

    before(async () => {
      const erc20Factory = await ethers.getContractFactory("TestERC20");
      erc20 = await erc20Factory.deploy(ethers.utils.parseEther("400000000"));
      erc20 = await erc20.deployed();

      const [signer1] = await ethers.getSigners();

      const allocatorFactory = await ethers.getContractFactory("Allocator");
      allocator = await allocatorFactory.deploy(signer1.address, erc20.address, 150);
      allocator = await allocator.deployed();
    });

    it("should allow to stake", async () => {
      await erc20.approve(allocator.address, ethers.utils.parseEther("500000"));
      expect(allocator.stake(ethers.utils.parseEther("500000"), 1)).to.emit(allocator, "Stake");
    });

    it("should retrieve weight", async () => {
      const [signer1] = await ethers.getSigners();
      console.log((await allocator.userWeight(signer1.address)).toString());
    });
  });
});
