import CollectionConfigInterface from "./CollectionConfigInterface";

let whitelistAddresses = [ "bla"];
const CollectionConfig: CollectionConfigInterface = {
  contractName: 'WalterTheRabbit',
  tokenName: 'WalterTheRabbit',//this becomes OpenSea's collection name
  tokenSymbol: 'WTR',
  hiddenMetadataUri: 'ipfs://QmRdvFsMt1WCJPWykycsZcqLVsKvz4jDPDzTCmGuDF37aE/hidden.json',
  maxSupply: 30,
  publicMetadataUri: "ipfs://bafybeicg735bmbyjms4cldllx2pl7ldmx4lrqw5dqxa5u5ujfb5faqoypq/", // sepolia v5.0
  contractMetadataUri: "https://waltertherabbit.com/contract_metadata.json", // v4.4 https
  dropUri: "https://waltertherabbit.com/",
  // upgradable seadrop WTR 4.1 https://sepolia.etherscan.io/address/0x5166C24EB60384561a13FF963B7d8366dB210EE2
  // https://testnets.opensea.io/collection/waltertherabbit-10/overview
  //contractAddress: "0x5166C24EB60384561a13FF963B7d8366dB210EE2",

  //Local hardhat
  contractAddress: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  marketplaceIdentifier: 'waltertherabbit',
  whitelistAddresses,
};

export default CollectionConfig;
