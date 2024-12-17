import { randomInt } from "crypto";
import { keccak256 } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import type { MintParamsStruct } from "../../typechain-types/src/SeaDrop";
import { AllowListDataStruct } from "../../typechain-types/WalterTheRabbit";


const toPaddedBuffer = (data: any) =>
  Buffer.from(
    ethers.BigNumber.from(data).toHexString().slice(2).padStart(64, "0"),
    "hex"
  );

const allowListElementsBuffer = (
  leaves: Array<[minter: string, mintParams: MintParamsStruct]>
) =>
  leaves.map(([minter, mintParams]) =>
    Buffer.concat(
      [
        minter,
        mintParams.mintPrice,
        mintParams.maxTotalMintableByWallet,
        mintParams.startTime,
        mintParams.endTime,
        mintParams.dropStageIndex,
        mintParams.maxTokenSupplyForStage,
        mintParams.feeBps,
        mintParams.restrictFeeRecipients ? 1 : 0,
      ].map(toPaddedBuffer)
    )
  );

const createMerkleTree = (leaves: Buffer[]) =>
  new MerkleTree(leaves, keccak256, {
    hashLeaves: true,
    sortLeaves: true,
    sortPairs: true,
  });

export const getAllowListData: (address: string) => Promise<AllowListDataStruct> = async (address: string) => {
  // Set the allow list mint params.
  const allowListMintParams = {
    mintPrice: "100000000000000000", // 0.1 ether
    maxTotalMintableByWallet: 11,
    startTime: Math.round(Date.now() / 1000) - 100,
    endTime: Math.round(Date.now() / 1000) + 3600,
    dropStageIndex: 1,
    maxTokenSupplyForStage: 10,
    feeBps: 500,//5%
    restrictFeeRecipients: true,
  };
  const mintParamsFreeMint = { ...allowListMintParams, mintPrice: 0 };

  const mintQuantity = Math.max(
    1,
    randomInt(mintParamsFreeMint.maxTotalMintableByWallet as number)
  );

// Encode the minter address and mintParams.
  const elementsBuffer = await allowListElementsBuffer([
    [address, mintParamsFreeMint],
  ]);

// Construct a merkle tree from the allow list elements.
  const merkleTree = createMerkleTree(elementsBuffer);

// Store the merkle root.
  const root = merkleTree.getHexRoot();

// Get the leaf at index 0.
  const leaf = merkleTree.getLeaf(0);

// Get the proof of the leaf to pass into the transaction.
  const proof = merkleTree.getHexProof(leaf);

// Declare the allow list data.
  const allowListData: AllowListDataStruct = {
    merkleRoot: root,
    publicKeyURIs: [],
    allowListURI: ""
  };

  return allowListData;
}
