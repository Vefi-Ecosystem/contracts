const { expect, use } = require("chai");
const { ethers, waffle } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");
const { BigNumber } = require("bignumber.js");

use(waffle.solidity);

describe("Tests", () => {
  describe("PresaleWithoutVesting", () => {
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
        (await time.latest()).toNumber() + 3600,
        (await time.latest()).toNumber() + 3600 * 24,
        ethers.utils.parseEther("7000"),
        signer1.address,
        1,
        signer1.address
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
      await expect(() => presale.fund(ethers.utils.parseEther("7000").toHexString())).to.changeTokenBalance(
        erc202,
        presale,
        ethers.utils.parseEther("7000")
      );
    });

    it("should not allow purchase before sale starts", async () => {
      await erc201.approve(presale.address, ethers.utils.parseEther("1000").toHexString());
      await expect(presale.purchase(ethers.utils.parseEther("1000").toHexString())).to.be.revertedWith("sale has not begun");
    });

    it("should allow purchase after sale starts", async () => {
      await time.increase(time.duration.hours(2));
      await expect(() => presale.purchase(ethers.utils.parseEther("1").toHexString())).to.changeTokenBalance(
        erc201,
        presale,
        ethers.utils.parseEther("1")
      );
    });

    it("should not permit withdrawals before end of sale", async () => {
      await expect(presale.withdraw()).to.be.revertedWith("can't withdraw before claim is started");
    });

    it("should permit withdrawals after end of sale", async () => {
      const [signer1] = await ethers.getSigners();
      await time.increase(time.duration.hours(24));
      await expect(() => presale.withdraw()).to.changeTokenBalance(erc202, signer1, ethers.utils.parseEther("0.001"));
    });
  });

  describe("PresaleWithLinearVesting", () => {
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
        (await time.latest()).toNumber() + 3600,
        (await time.latest()).toNumber() + 3600 * 24,
        ethers.utils.parseEther("7000"),
        signer1.address,
        1,
        signer1.address
      );
      presale = await presale.deployed();
    });

    it("should allow funding by funder", async () => {
      await erc202.approve(presale.address, ethers.utils.parseEther("7000").toHexString());
      await expect(() => presale.fund(ethers.utils.parseEther("7000").toHexString())).to.changeTokenBalance(
        erc202,
        presale,
        ethers.utils.parseEther("7000")
      );
    });

    it("should allow only owner to set vesting", async () => {
      const [, signer2] = await ethers.getSigners();
      const vestingEndTime = (await presale.withdrawTime()).add(3600);
      await expect(presale.connect(signer2).setLinearVestingEndTime(vestingEndTime)).to.be.reverted;
    });

    it("should allow vesting to be set", async () => {
      const vestingEndTime = (await presale.withdrawTime()).add(3600);
      await expect(presale.setLinearVestingEndTime(vestingEndTime)).to.emit(presale, "SetLinearVestingEndTime");
    });

    it("should allow purchase after sale starts", async () => {
      await time.increase(time.duration.hours(2));
      await erc201.approve(presale.address, ethers.utils.parseEther("1").toHexString());
      await expect(() => presale.purchase(ethers.utils.parseEther("1").toHexString())).to.changeTokenBalance(
        erc201,
        presale,
        ethers.utils.parseEther("1")
      );
    });
  });
});
