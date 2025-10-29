import "@nomicfoundation/hardhat-ethers";


import { ethers } from "hardhat";

async function main() {
  console.log("Deploying DisasterReliefFund...");

  const DisasterReliefFund = await ethers.getContractFactory("DisasterReliefFund");

  // Example owners and threshold
  const owners = [
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // default Hardhat account 1
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // default Hardhat account 2
  ];
  const required = 2; // number of required approvals

  const disasterReliefFund = await DisasterReliefFund.deploy(owners, required);

  await disasterReliefFund.waitForDeployment();

  console.log("DisasterReliefFund deployed to:", await disasterReliefFund.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
