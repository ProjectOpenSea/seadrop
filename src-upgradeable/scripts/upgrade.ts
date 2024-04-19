import fs from "fs";
import { ethers, upgrades } from "hardhat";

async function main() {
  const ERC721SeaDropUpgradeable = await ethers.getContractFactory("ERC721SeaDropUpgradeable");

  console.log("Upgrading...");

  let addresses = JSON.parse(
    fs.readFileSync("deployment-addresses.json").toString()
  );

  const result = await upgrades.upgradeProxy(addresses.proxy, ERC721SeaDropUpgradeable);
  await result.deployTransaction.wait();

  console.log("Upgraded");

  addresses = {
    proxy: addresses.proxy,
    admin: await upgrades.erc1967.getAdminAddress(addresses.proxy),
    implementation: await upgrades.erc1967.getImplementationAddress(
      addresses.proxy
    ),
  };
  console.log("Addresses: ", addresses);

  try {
    await (run as any)("verify", { address: addresses.implementation });
  } catch (e) {}

  fs.writeFileSync("deployment-addresses.json", JSON.stringify(addresses));
}

main();
