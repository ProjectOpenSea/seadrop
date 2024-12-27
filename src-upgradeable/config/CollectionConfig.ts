import CollectionConfigInterface from "./CollectionConfigInterface";

let whitelistAddresses = [ "bla"];
const CollectionConfig: CollectionConfigInterface = {
  // localnet: Networks.hardhatLocal,
  // testnet: Networks.ethereumTestnet,
  // mainnet: Networks.ethereumMainnet,
  contractName: 'WalterTheRabbit',
  tokenName: 'WalterTheRabbit',//this becomes OpenSea's collection name
  tokenSymbol: 'WTR',
  hiddenMetadataUri: 'ipfs://QmRdvFsMt1WCJPWykycsZcqLVsKvz4jDPDzTCmGuDF37aE/hidden.json',
  maxSupply: 23,
  // whitelistSale: {
  //   price: 0.002,
  //   maxMintAmountPerTx: 10,
  // },
  // preSale: {
  //   price: 0.007,
  //   maxMintAmountPerTx: 10,
  // },
  // publicSale: {
  //   price: 0.01,
  //   maxMintAmountPerTx: 5,
  // },
  publicMetadataUri: "ipfs://QmW84YjXWpvh6GrVBTvuHyavoCY7wfirZ4Uq65SqVe1wDm/",
  contractMetadataUri: "ipfs://QmUk5F2gUs95MNPvqGkDe1BidiR77qf8dwfz5t9DdF4tvi",
  dropUri: "https://waltertherabbit.com/drop",
  // contractAddress: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",//upgradable local node v1
  // contractAddress: "0x7a2088a1bFc9d81c55368AE168C2C02570cB814F",//upgradable local node v2
  // contractAddress: "0xBDE61d4a30b5d9497407D7Cd950283eD0006f162",//upgradable sepolia v2 https://testnets.opensea.io/collection/waltertherabbit-2
  contractAddress: "0x749ed97da028d932EE8f6aBef0bB8B43B58B05D6",//upgradable seadrop WTR https://testnets.opensea.io/collection/waltertherabbit-8/overview
  marketplaceIdentifier: 'waltertherabbit',
  whitelistAddresses,
};

export default CollectionConfig;
