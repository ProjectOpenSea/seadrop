import fs from "fs";
import { ethers, upgrades } from "hardhat";

async function mainDeploy() {
  const CapsuleChests = await ethers.getContractFactory("CapsuleChests");
  console.log("Deploying...");
  const capsuleChests = await upgrades.deployProxy(
    CapsuleChests,
    [
      "CHCC: Genesis Collection Chest",
      "CHCC-GCC",
      "0x4468A5B725E2C63056131121cD33b66848E1dd87",
      ["0x00005EA00Ac477B1030CE78506496e8C2dE24bf5"],
    ],
    { initializer: "initialize" }
  );
  await capsuleChests.deployed();
  const addresses = {
    proxy: capsuleChests.address,
    admin: await upgrades.erc1967.getAdminAddress(capsuleChests.address),
    implementation: await upgrades.erc1967.getImplementationAddress(
      capsuleChests.address
    ),
  };
  console.log("Addresses:", addresses);

  try {
    await (run as any)("verify", { address: addresses.implementation });
  } catch (e) {}

  fs.writeFileSync("deployment-addresses.json", JSON.stringify(addresses));
}

mainDeploy();
