import fs from "fs";
import { ethers, upgrades } from "hardhat";

async function mainDeploy() {
  const ERC721SeaDropUpgradeable = await ethers.getContractFactory("ERC721SeaDropUpgradeable");

  console.log("Deploying...");

  const tokenName = "ERC721SeaDropUpgradeable"
  const tokenSymbol = "SD"
  const allowedSeaDrop = ["0x00005EA00Ac477B1030CE78506496e8C2dE24bf5"]

  const token = await upgrades.deployProxy(
    ERC721SeaDropUpgradeable,
    [
      tokenName,
      tokenSymbol,
      allowedSeaDrop,
    ],
    { initializer: "initialize" }
  );

  await token.deployed();

  const addresses = {
    proxy: token.address,
    admin: await upgrades.erc1967.getAdminAddress(token.address),
    implementation: await upgrades.erc1967.getImplementationAddress(
      token.address
    ),
  };
  console.log("Addresses: ", addresses);

  try {
    await (run as any)("verify", { address: addresses.implementation });
  } catch (e) {}

  fs.writeFileSync("deployment-addresses.json", JSON.stringify(addresses));
}

mainDeploy();
