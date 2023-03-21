const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bankless", function() {
  let bankless;
  let owner;
  let alice;
  let bob;
  
  beforeEach(async function() {
    [owner, alice, bob] = await ethers.getSigners();
    const Bankless = await ethers.getContractFactory("Bankless");
    bankless = await Bankless.deploy();
    await bankless.deployed();
  });
  
  it("should allow Alice to deposit ETH and withdraw it", async function() {
    // Alice deposits 1 ETH
    const depositAmount = ethers.utils.parseEther("1");
    const uniqueChars = await bankless.deposit({ value: depositAmount, from: alice.address });
    
    // Check that Alice's balance has increased
    const aliceBalance = await bankless.balances(alice.address);
    expect(aliceBalance).to.equal(depositAmount.mul(9).div(10)); // 10% fee deducted
    
    // Alice withdraws her ETH
    const tx = await bankless.withdraw(uniqueChars, alice.address, alice.address, aliceBalance);
    await tx.wait();
    
    // Check that Alice's balance has returned to zero
    const newAliceBalance = await bankless.balances(alice.address);
    expect(newAliceBalance).to.equal(0);
  });
  
  it("should not allow a withdrawal to the deposit address", async function() {
    // Alice deposits 1 ETH
    const depositAmount = ethers.utils.parseEther("1");
    const uniqueChars = await bankless.deposit({ value: depositAmount, from: alice.address });
    
    // Bob tries to withdraw to Alice's deposit address (which is invalid)
    await expect(bankless.withdraw(uniqueChars, bob.address, alice.address, depositAmount)).to.be.revertedWith("Withdrawal address must be different from deposit address");
  });
  
  it("should not allow a withdrawal with insufficient balance", async function() {
    // Alice deposits 1 ETH
    const depositAmount = ethers.utils.parseEther("1");
    const uniqueChars = await bankless.deposit({ value: depositAmount, from: alice.address });
    
    // Bob tries to withdraw more than the balance
    await expect(bankless.withdraw(uniqueChars, bob.address, alice.address, depositAmount.add(1))).to.be.revertedWith("Insufficient balance");
  });
  
  it("should allow the owner to withdraw fees", async function() {
    // Alice deposits 1 ETH
    const depositAmount = ethers.utils.parseEther("1");
    const uniqueChars = await bankless.deposit({ value: depositAmount, from: alice.address });
    
    // Check that the owner's balance has increased
    const ownerBalance = await bankless.balances(owner.address);
    expect(ownerBalance).to.equal(depositAmount.div(10)); // 10% fee
    
    // Owner withdraws the fees
    const tx = await bankless.withdrawFees({ from: owner.address });
    await tx.wait();
    
    // Check that the owner's balance has returned to zero
    const newOwnerBalance = await bankless.balances(owner.address);
    expect(newOwnerBalance).to.equal(0);
  });
});
