import { ethers } from "ethers";
import { MerkleTree } from "merkletreejs";

import { toPaddedBuffer } from "./encoding";

import type { SeaDropStructsErrorsAndEvents } from "../../typechain-types/src/shim/Shim";
import type { Wallet } from "ethers";

type MintParamsStruct = SeaDropStructsErrorsAndEvents.MintParamsStruct;

const { keccak256 } = ethers.utils;

const createMerkleTree = (leaves: Buffer[]) =>
  new MerkleTree(leaves, keccak256, {
    hashLeaves: true,
    sortLeaves: true,
    sortPairs: true,
  });

type Leaf = [minter: string, mintParams: MintParamsStruct];

export const allowListElementsBuffer = (leaves: Leaf[]) =>
  leaves.map(([minter, mintParams]) =>
    Buffer.concat(
      [
        minter,
        mintParams.mintPrice,
        mintParams.paymentToken,
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

export const createAllowListAndGetProof = async (
  minters: Wallet[],
  mintParams: MintParamsStruct,
  minterIndexForProof = 0
) => {
  // Construct the leaves.
  const leaves = minters.map((minter) => [minter.address, mintParams] as Leaf);

  // Encode the leaves.
  const elementsBuffer = await allowListElementsBuffer(leaves);

  // Construct a merkle tree from the allow list elements.
  const merkleTree = createMerkleTree(elementsBuffer);

  // Get the merkle root.
  const root = merkleTree.getHexRoot();

  // Get the leaf at the specified index.
  const targetLeaf = Buffer.from(
    keccak256(elementsBuffer[minterIndexForProof]).slice(2),
    "hex"
  );
  const leafIndex = merkleTree.getLeafIndex(targetLeaf);
  const leaf = merkleTree.getLeaf(leafIndex);

  // Get the proof of the leaf to pass to the order.
  const proof = merkleTree.getHexProof(leaf);

  return { root, proof };
};
