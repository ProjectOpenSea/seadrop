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

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    await faucet(owner.address, provider);
    await faucet(admin.address, provider);

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

  it("Should not let a non-INonFungibleSeaDropToken token contract use the token methods", async () => {
    await whileImpersonating(
      vanillaToken.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          seadrop.connect(impersonatedSigner).updateDropURI("http://test.com")
        ).to.be.revertedWith("OnlyINonFungibleSeaDropToken");
      }
    );

    await expect(
      token.connect(owner).updateDropURI(seadrop.address, "http://test.com")
    )
      .to.emit(seadrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");
  });
});
