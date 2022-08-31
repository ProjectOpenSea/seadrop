import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ERC721PartnerSeaDrop,
  IERC721,
  ISeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721PartnerSeaDrop;
  let vanillaToken: IERC721;
  let owner: Wallet;
  let admin: Wallet;
  let minter: Wallet;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, admin, minter]) {
      await faucet(wallet.address, provider);
    }

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();

    // Deploy token
    const ERC721PartnerSeaDrop = await ethers.getContractFactory(
      "ERC721PartnerSeaDrop",
      owner
    );
    token = await ERC721PartnerSeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);

    // Deploy vanilla (non-IER721SeaDrop) token
    const ERC721A = await ethers.getContractFactory("ERC721A", owner);
    vanillaToken = (await ERC721A.deploy("", "")) as unknown as IERC721;
  });

  it("Should not let a non-IERC721SeaDrop token contract use the token methods", async () => {
    await whileImpersonating(
      vanillaToken.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          seadrop.connect(impersonatedSigner).updateDropURI("http://test.com")
        ).to.be.revertedWith("OnlyIERC721SeaDrop");
      }
    );

    await expect(
      token.connect(owner).updateDropURI(seadrop.address, "http://test.com")
    )
      .to.emit(seadrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");
  });

  it("Should not allow reentrancy during mint", async () => {
    // Set a public drop with maxTotalMintableByWallet: 1
    // and restrictFeeRecipient: false
    await token.setMaxSupply(10);
    const oneEther = ethers.utils.parseEther("1");
    const publicDrop = {
      mintPrice: oneEther,
      maxTotalMintableByWallet: 1,
      startTime: Math.round(Date.now() / 1000) - 100,
      feeBps: 1000,
      restrictFeeRecipients: false,
    };
    await token.connect(admin).updatePublicDrop(seadrop.address, publicDrop);

    const MaliciousRecipientFactory = await ethers.getContractFactory(
      "MaliciousRecipient",
      owner
    );
    const maliciousRecipient = await MaliciousRecipientFactory.deploy();

    // Set the creator address to MaliciousRecipient.
    await token
      .connect(owner)
      .updateCreatorPayoutAddress(seadrop.address, maliciousRecipient.address);

    // Should not be able to mint with reentrancy.
    await expect(
      maliciousRecipient.attack(seadrop.address, token.address, {
        value: oneEther.mul(2),
      })
    ).to.be.revertedWith("ETH_TRANSFER_FAILED");
    expect(await token.totalSupply()).to.eq(0);
  });
});
