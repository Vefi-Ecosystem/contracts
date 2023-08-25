const { expect, use } = require("chai");
const { ethers, waffle } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");
const { BigNumber } = require("bignumber.js");

use(waffle.solidity);

describe("Tests", () => {
  describe("Allocator_Sale", () => {
    /**
     * @type {import('ethers').Contract}
     */
    let erc20;

    /**
     * @type {import('ethers').Contract}
     */
    let erc202;

    /**
     * @type {import('ethers').Contract}
     */
    let allocator;

    /**
     * @type {import('ethers').Contract}
     */
    let presaleFactory;

    before(async () => {
      const erc20Factory = await ethers.getContractFactory("TestERC20");
      erc20 = await erc20Factory.deploy(ethers.utils.parseEther("400000000"));
      erc20 = await erc20.deployed();

      erc202 = await erc20Factory.deploy(ethers.utils.parseEther("400000000"));
      erc202 = await erc202.deployed();

      const [signer1] = await ethers.getSigners();

      const allocatorFactory = await ethers.getContractFactory("Allocator");
      allocator = await allocatorFactory.deploy(signer1.address, erc20.address, 150);
      allocator = await allocator.deployed();

      const presaleFactoryFactory = await ethers.getContractFactory("PresaleFactory");
      presaleFactory = await presaleFactoryFactory.deploy(10, signer1.address, allocator.address);
      presaleFactory = await presaleFactory.deployed();

      const allocationSale = await ethers.getContractFactory("AllocationSale");
      let c = await allocationSale.deploy(
        "",
        signer1.address,
        ethers.utils.parseEther("0.00003"),
        erc20.address,
        erc202.address,
        Math.floor(Date.now() / 1000),
        Math.floor(Date.now() / 1000) + 60 * 84600,
        ethers.utils.parseEther("30"),
        signer1.address,
        4,
        signer1.address,
        allocator.address
      );

      c = await c.deployed();
      console.log(c.address);
    });

    it("should allow to stake", async () => {
      await erc20.approve(allocator.address, ethers.utils.parseEther("500000"));
      expect(allocator.stake(ethers.utils.parseEther("500000"), 1)).to.emit(allocator, "Stake");
    });

    it("should retrieve weight", async () => {
      const [signer1] = await ethers.getSigners();
      console.log((await allocator.userWeight(signer1.address)).toString());
    });

    it("should create allocation sale", async () => {
      const [signer1] = await ethers.getSigners();
      const allocationSale = await ethers.getContractFactory("AllocationSale");
      await expect(
        presaleFactory.deploySale(
          allocationSale.bytecode,
          "",
          signer1.address,
          signer1.address,
          signer1.address,
          ethers.utils.parseEther("0.00003"),
          erc20.address,
          erc202.address,
          Math.floor(Date.now() / 1000),
          3,
          ethers.utils.parseEther("0.003"),
          ethers.utils.parseEther("10"),
          [],
          [],
          20,
          1,
          {gasLimit: 400807922}
        )
      ).to.emit(presaleFactory, "PresaleCreated");
    });
  });
});
