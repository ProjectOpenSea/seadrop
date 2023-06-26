forge script script/DeployRaribleDrop.s.sol:DeployRaribleDrop --rpc-url $POLYGON_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --etherscan-api-key $ETHERSCAN_POLYGON --verify
forge script script/DeployRaribleDrop.s.sol:DeployRaribleDrop --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --etherscan-api-key $ETHERSCAN_GOERLI --verify

forge script script/DeployRaribleDropCloneFactory.s.sol:DeployRaribleDropCloneFactory --rpc-url $POLYGON_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --etherscan-api-key $ETHERSCAN_POLYGON --verify
forge script script/DeployRaribleDropCloneFactory.s.sol:DeployRaribleDropCloneFactory --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY -vvvv --broadcast --etherscan-api-key $ETHERSCAN_GOERLI --verify