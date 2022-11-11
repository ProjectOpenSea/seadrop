git checkout main;

# Download the latest ERC721A.
echo "Getting latest ERC721A";
if [[ -f "ERC721A/package.json" ]]; then
	cd ERC721A;
	git fetch --all; 
	git reset --hard origin/main;
	cd ..;
else
	git clone https://github.com/chiru-labs/ERC721A.git;
fi

# Get the last commit hash of ERC721A
cd ./ERC721A;
commit="$(git rev-parse HEAD)";
cd ..;

# Replace the contracts and test folder with the latest copy.
rm -r ./contracts;
rm -r ./test;
rsync -av --progress ERC721A/ ./ \
	--exclude README.md \
	--exclude projects.md \
	--exclude hardhat.config.js \
	--exclude .github/ \
	--exclude .git/ \
	--exclude docs/ \
	--exclude scripts/ \
	--exclude package.json \
	--exclude package-lock.json;
rm -rf ./ERC721A;

# Recompile the contracts.
npx hardhat clean;
npx hardhat compile;

# Transpile.
echo "Transpiling";
# -D: delete original and excluded files
# -E: extract storage for Diamond Pattern
npx @gnus.ai/upgrade-safe-transpiler-diamond -D -E;
node scripts/replace-imports.js;
(npm run lint:sol) || true;

# Commit and push
echo "Committing latest code";
git config user.name 'github-actions';
git config user.email '41898282+github-actions[bot]@users.noreply.github.com';
git add -A;
(git commit -m "Transpile chiru-labs/ERC721A@$commit" && git push origin main) || echo "No changes to commit";
