const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ProductTraceability", function () {
  async function deployFixture() {
    const [owner, manufacturer, retailer1, retailer2, other] =
      await ethers.getSigners();

    const Contract = await ethers.getContractFactory("ProductTraceability");
    const contract = await Contract.deploy();

    // Allowlist one manufacturer and one retailer
    await contract.setManufacturer(manufacturer.address, true);
    await contract.setRetailer(retailer1.address, true);
    await contract.setRetailer(retailer2.address, true);

    return { contract, owner, manufacturer, retailer1, retailer2, other };
  }

  it("allows only allowlisted manufacturer to create product", async function () {
    const { contract, manufacturer, other } = await deployFixture();

    await expect(
      contract.connect(other).createProduct("P1", "LocA")
    ).to.be.revertedWith("Not allowed manufacturer");

    await expect(
      contract.connect(manufacturer).createProduct("P1", "LocA")
    ).to.emit(contract, "ProductCreated");
  });

  it("prevents duplicate product IDs", async function () {
    const { contract, manufacturer } = await deployFixture();

    await contract.connect(manufacturer).createProduct("P1", "LocA");
    await expect(
      contract.connect(manufacturer).createProduct("P1", "LocB")
    ).to.be.revertedWith("Product already exists");
  });

  it("allows only allowlisted retailer to add hops", async function () {
    const { contract, manufacturer, retailer1, other } = await deployFixture();

    await contract.connect(manufacturer).createProduct("P1", "LocA");

    await expect(
      contract.connect(other).addRetailerHop("P1", "RetailLoc")
    ).to.be.revertedWith("Not allowed retailer");

    await expect(
      contract.connect(retailer1).addRetailerHop("P1", "RetailLoc")
    ).to.emit(contract, "HopAdded");
  });

  it("returns correct history with manufacturer and multiple retailers", async function () {
    const { contract, manufacturer, retailer1, retailer2 } =
      await deployFixture();

    await contract.connect(manufacturer).createProduct("P1", "ManuLoc");
    await contract.connect(retailer1).addRetailerHop("P1", "RetailLoc1");
    await contract.connect(retailer2).addRetailerHop("P1", "RetailLoc2");

    const [id, manuAddress, history] = await contract.getProduct("P1");
    expect(id).to.equal("P1");
    expect(manuAddress).to.equal(manufacturer.address);
    expect(history.length).to.equal(3); // 1 manufacturer + 2 retailer hops

    expect(history[0].role).to.equal(0); // Manufacturer enum
    expect(history[0].actor).to.equal(manufacturer.address);
    expect(history[0].location).to.equal("ManuLoc");

    expect(history[1].role).to.equal(1); // Retailer enum
    expect(history[1].actor).to.equal(retailer1.address);
    expect(history[1].location).to.equal("RetailLoc1");

    expect(history[2].role).to.equal(1); // Retailer enum
    expect(history[2].actor).to.equal(retailer2.address);
    expect(history[2].location).to.equal("RetailLoc2");
  });

  it("prevents the same retailer from adding multiple hops for the same product", async function () {
    const { contract, manufacturer, retailer1 } = await deployFixture();

    await contract.connect(manufacturer).createProduct("P2", "ManuLoc");
    await contract.connect(retailer1).addRetailerHop("P2", "RetailLoc1");

    await expect(
      contract.connect(retailer1).addRetailerHop("P2", "RetailLocAgain")
    ).to.be.revertedWith("Retailer already added for product");
  });

  it("prevents adding hops after product is completed", async function () {
    const { contract, manufacturer, retailer1 } = await deployFixture();

    await contract.connect(manufacturer).createProduct("P3", "ManuLoc");
    await contract.connect(retailer1).addRetailerHop("P3", "RetailLoc1");

    await expect(contract.connect(manufacturer).completeProduct("P3")).to.emit(
      contract,
      "ProductCompleted"
    );

    await expect(
      contract.connect(retailer1).addRetailerHop("P3", "RetailLoc2")
    ).to.be.revertedWith("Product not active");
  });

  it("allows only manufacturer or owner to complete product", async function () {
    const { contract, owner, manufacturer, retailer1, other } =
      await deployFixture();

    await contract.connect(manufacturer).createProduct("P4", "ManuLoc");

    await expect(
      contract.connect(retailer1).completeProduct("P4")
    ).to.be.revertedWith("Not authorized to complete");

    await expect(
      contract.connect(other).completeProduct("P4")
    ).to.be.revertedWith("Not authorized to complete");

    await expect(contract.connect(owner).completeProduct("P4")).to.emit(
      contract,
      "ProductCompleted"
    );
  });

  it("supports transferring and renouncing ownership", async function () {
    const { contract, owner, other } = await deployFixture();

    // transfer ownership
    await expect(
      contract.connect(owner).transferOwnership(other.address)
    ).to.emit(contract, "OwnershipTransferred");

    expect(await contract.owner()).to.equal(other.address);

    // only new owner can call owner-only functions
    await expect(
      contract.connect(owner).setManufacturer(owner.address, true)
    ).to.be.revertedWith("Not owner");

    await contract.connect(other).setManufacturer(other.address, true);

    // renounce ownership
    await expect(contract.connect(other).renounceOwnership()).to.emit(
      contract,
      "OwnershipTransferred"
    );

    expect(await contract.owner()).to.equal(ethers.ZeroAddress);
  });
});
