# Walter the Rabbit NFT Collection

### Build

    yarn build


### Smart Contract

    yarn accounts

### Test

#### After deploy tests on truffle 
Truffle can be connected to 
    - localnode
    - sepolia
    - mainnet

#### Local Node Full Tests

Run hardhat local node (accounts are printed with yarn accounts to get priv keys and use in wallets and trx, etc)
    
    yarn local-node

Run full tests on the local node hardhat network
    
    yarn test --network hardhat --show-stack-traces
    
    

### Release
1. Upload to IPFS (piñata.cloud)

    - 1.1 Upload the images folder (if there's animation replace the .png with a webp animated and update the metadata file too)
    
      - 1.2 After the images are uploaded update metadata files in NFTGenerator (output/metadata/*.json) to replace the CID 
        QmdYnyMJoGztyaNRCwKFRUyCDrK7sTMyi2Bg2kVsvDkNiL with the latest.

            grep -rl matchstring somedir/ | xargs sed -i 's/string1/string2/g'
            #or
            grep -rl bafybeibqazuju2mz4hmtucvqnbly67fdisygil7kze6gxdhdbz3e44wfuq . | xargs sed -i 's/bafybeibqazuju2mz4hmtucvqnbly67fdisygil7kze6gxdhdbz3e44wfuq/bafybeibtwgyqaqntwlfsrggmlpng5xdd3x2hz6ju3vo2oyiebb2boy6ysy/g'            
            #or
            # find /path/to/files -type f -exec sed -i 's/oldstring/new string/g' {} \;
        
    - 1.3 Upload metadata folder's content (no ./metadata just the .jsons) and write down metadata CID
    
    - 1.4 Update metadata CID into smart-contract/CollectionConfig (both hidden and public)
    
    - 1.5 Contract Level Metadata

                  Upload a json file metadata to CID
                  Add contract-metadata to smart-contract/CollectionConfig
                  see https://docs.opensea.io/docs/contract-level-metadata
            
2. Update Collection Metadata IPFS URI  

**DEPRECATED** In CollectionConfig.ts Now need to call the update method on the contract
        
Seadrop compatible:

        console.log(`setting baseURI to ${CollectionConfig.publicMetadataUri}`);
        await token.setBaseURI(CollectionConfig.publicMetadataUri);


   2.1 Update ipfs uris for [ publicMetadataUri, hiddenMetadataUri]

   2.2 Update maxSupply with the number from the uploaded collection
   

3. Build smart contract

            yarn compile

4. Deploy smart contract (needs gas)
            yarn test --network localhost
            yarn deploy2 --network truffle
            ## yarn verify 0x5FbDB2315678afecb367f032d93F642f64180aa3 #contract address on seplia
            yarn verify 0x5FbDB2315678afecb367f032d93F642f64180aa3 --network truffle

    4.1 Deploy contract upgrade to existing proxy


        yarn upgrade-contract --network truffle
           yarn run v1.22.19
           hardhat run scripts/1_deploy_v2_upgrade.ts --network truffle
           Deploying upgrade to contract on address
           verify contract 0xBDE61d4a30b5d9497407D7Cd950283eD0006f162.
           wait over. proxy deployed to address: 0xBDE61d4a30b5d9497407D7Cd950283eD0006f162
           Addresses: {
           proxy: '0xBDE61d4a30b5d9497407D7Cd950283eD0006f162',
           admin: '0x6861A19e86e7F87EFFCFf99057aFAbD0FE52F061',
           implementation: '0x0C062CabAB8A5d8d63F8f59758A0751F2c7123FF'
           }
           Done in 5.94s.

* Possible errors
    * Error: factory runner does not support sending transactions (operation="sendTransaction", code=UNSUPPORTED_OPERATION, version=6.13.0)
    * Check that truffle is running and connected to a wallet in the correct network





5. Check the mints in Opensea
    
        Test Release 1 on Goerli
        https://testnets.opensea.io/assets/goerli/0xd96adaabd8f1a3b5a3dd30a52fe65ecac35b8b9f/4

        Test Release 1 on Sepolia
        https://testnets.opensea.io/assets/sepolia/ TODO /1

### Contract Metadata

Update contract metadata uri in CollectionConfig. 


       contractMetadataUri: "ipfs://QmUk5F2gUs95MNPvqGkDe1BidiR77qf8dwfz5t9DdF4tvi",
v42
    bafkreieffnh6fchiap5vrlhltgdbqeac7bog3v36u4hsym3inla2zoncqi

with content:

    {
      "name": "Walter the Rabbit",
      "description": "Welcome to the mystical, magical world of Walter the Rabbit NFTs. 100% hand drawn by a real human artist. No generative AI sh!*t here. Countless different characters with unique back stories that will hit you before you even try it! It's the first foundational step towards the Walter the Rabbit video game.",
      "image": "https://waltertherabbit.com/image.png",
      "banner_image": "https://waltertherabbit.com/banner-image.png",
      "featured_image": "https://waltertherabbit.com/featured-image.png",
      "external_link": "https://waltertherabbit.com/",
      "collaborators": [ ]
    }



## Deploy Cost & Optimizations

### Deployment cost estimation

Aall trx
https://sepolia.etherscan.io/txs?a=0x749ed97da028d932ee8f6abef0bb8b43b58b05d6

Seadrop compatible Upgradeable ERC721A based contract
https://testnets.opensea.io/collection/waltertherabbit-8/overview

Deployment
https://sepolia.etherscan.io/address/0x749ed97da028d932ee8f6abef0bb8b43b58b05d6


on sepolia (https://sepolia.etherscan.io/address/0x749ed97da028d932ee8f6abef0bb8b43b58b05d6)
Trx: https://sepolia.etherscan.io/tx/0x99e2478b0617cc0c4bcc433fcfc6e47536eabffe2920c3748d9ab9d69fe71d37
        
on mainnet (https://etherscan.io/gastracker)

      Gas Price:  36.281 Gwei (0.000000036281 ETH)
      Cost = Gas Price x Amount of Gas Consumed
           = 0.000000036281 ETH * 844049
           = 0.030622942 ETH * 2500 USD/ETH
           = 76.57 USD (assuming eth 2500)


Another example:
https://sepolia.etherscan.io/tx/0xdf7a743fa59f559fb6829cbe7aafdb49769da42dffd10f106a2524e313227180
        
        =  * 5251310
        = 0.0099599008399301 ETH
        = 23.4 USD
        gas price 1.880818164 Gwei (0.000000001880818164 ETH)

### Upgrade estimate
https://sepolia.etherscan.io/tx/0x03a456150519129a08582a7d3f70b3cadd51db39a532816c39374342899a3baa


### Multiconfigure contract cost 
So you can estimate current cost for the user on mainnet by taking a current gas fee and multiplying it by the limit used for your contract call.
    
* Codebase 
  1. Set all mandatory fields besides the drop / allow data.
  https://sepolia.etherscan.io/tx/0xe17605e482e732470b9b3110708070428e224a176936410424bb332c096495de 
 
          Gas Price: 44.457455915 Gwei (0.000000044457455915 ETH)
          Gas Limit: 1140856
          Cost = Gas Price x Amount of Gas Consumed for Multiconf
           = 0.000000044457455915 ETH * 68,851
           = 0.001587502690506036 ETH * 2507 USD/ETH
           = 7.673777325 USD (assuming eth 2507)
  2. Setting Allowlist Data which still don't know if it worked
  https://sepolia.etherscan.io/tx/0x7c942c1c281a7a4bed07db7955720d114bde8d85726f0b36996e2566de0cf357

          Gas Price: 11.93 Gwei (0.000000011938341834 ETH)
          Gas Limit: 1140856 Gas Used: 127757
          Cost = Gas Price x Amount of Gas Consumed for Multiconf
           = 0.000000011938341834 ETH * 127757
           = 0.001587502690506036 ETH * 2332 USD/ETH
           = 3.556782112 USD (assuming eth 2332)
        
        



* Opensea Editor.

    1- https://sepolia.etherscan.io/tx/0xdadb2e54bc08a46247cfc996117f21d55db5d8bc130293600e98d38b6bb65312 

            Gas Price: 44.457455915 Gwei (0.000000044457455915 ETH)
            Gas Limit: 1140856 gas used 68851
            Cost = Gas Price x Amount of Gas Consumed for Multiconf
             = 0.000000044457455915 ETH * 68851
             = 0.001587502690506036 ETH * 2507 USD/ETH
             = 7.673777325 USD (assuming eth 2507)

    2- https://sepolia.etherscan.io/tx/0xf1880bd4a756a820f6215bb5493e6bd4d7fc368cfbc7f54b3ae489d8e3a353e6

          Gas Price: 14.49 Gwei (0.000000014497750574 ETH)
          Gas Limit: 123839  Gas Used: 93353
          Cost = Gas Price x Amount of Gas Consumed for Multiconf
           = 0.000000014497750574 ETH * 93353
           = 0.001587502690506036 ETH * 2332 USD/ETH
           = 3.15 USD (assuming eth 2332)

* on mainnet
 
    https://etherscan.io/gastracker 
            
          Gas Limit: 1140856 gas used 68851
            7.673777325 USD

### Software
- [Typescript code](https://code.visualstudio.com/) (with the [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) extension)
- [NodeJs](https://nodejs.org/) (with the [Yarn package manager](https://yarnpkg.com/getting-started/install))


#### Improvements over the starting point fork
    - Remove private keys from the environment
        Private keys for wallets needed to be in the enviroment variables or .env file for contract operations and tests to work. 
        This is ok for local nodes, but not for test/prod enviroments. 
        Now it uses a signing wallet via truffle dashboard, which can be connected with metamask, etc. 
    - Contract is now Upgradable using erc721a-upgradeable/contracts/ERC721AUpgradeable.sol
        TODO Remove all individual mutators from the contract like setWhitelistEnabled, setCost, etc. Since we can now just upgrade the implementation no need
        to have all of this granular mutators that require more transactions to be executed.


### Services
- Etherscan free API key _(optional: used for the automated contract verification, as well as retrieving the current values for gas cost estimation)_
- Infura free basic plan or higher _(optional: used by the CLI commands in order to perform operations on real blockchains, you can skip this if you deploy and manage your contract [using Truffle Dashboard](https://youtu.be/fwdIA5UuPmM))_
- Coin Market Cap free API key _(optional: used for retrieving the current token price for gas cost estimation in USD)_



## Releases

Test - Sepolia

### WTR41 metadata CID 20 items
WTR 4.1 https://sepolia.etherscan.io/address/0x5166C24EB60384561a13FF963B7d8366dB210EE2 
https://testnets.opensea.io/collection/waltertherabbit-10/overview

    bafybeibtwgyqaqntwlfsrggmlpng5xdd3x2hz6ju3vo2oyiebb2boy6ysy
    
This is one has a bad 1.png image
    bafybeigqtx4rqxi3iq3yhibteiiu264axhswjyz5ah2ewly2pky3junx4m



### References

    ERC-721-C https://medium.com/limit-break/introducing-erc721-c-a-new-standard-for-enforceable-on-chain-programmable-royalties-defaa127410
    https://docs.opensea.io/docs/contract-level-metadata
