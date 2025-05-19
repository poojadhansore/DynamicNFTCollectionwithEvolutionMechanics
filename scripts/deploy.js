const { ethers } = require("hardhat");
const { verify } = require("../utils/verify");

async function main() {
  console.log("🚀 Starting deployment of DynamicNFTCollectionwithEvolutionMechanics...\n");

  // Get the contract factory
  const DynamicNFTCollection = await ethers.getContractFactory("DynamicNFTCollectionwithEvolutionMechanics");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  const deployerBalance = await ethers.provider.getBalance(deployerAddress);

  console.log("📋 Deployment Details:");
  console.log("🔑 Deployer address:", deployerAddress);
  console.log("💰 Deployer balance:", ethers.formatEther(deployerBalance), "ETH");
  console.log("🌐 Network:", (await ethers.provider.getNetwork()).name);
  console.log("⛽ Gas price:", ethers.formatUnits(await ethers.provider.getFeeData().then(fd => fd.gasPrice), "gwei"), "Gwei");
  
  // Estimate deployment cost
  const deploymentTx = DynamicNFTCollection.getDeployTransaction();
  const estimatedGas = await ethers.provider.estimateGas(deploymentTx);
  const gasPrice = (await ethers.provider.getFeeData()).gasPrice;
  const estimatedCost = estimatedGas * gasPrice;
  
  console.log("📊 Estimated deployment cost:", ethers.formatEther(estimatedCost), "ETH");
  console.log("\n⏳ Deploying contract...");

  // Deploy the contract
  const dynamicNFT = await DynamicNFTCollection.deploy();
  await dynamicNFT.waitForDeployment();

  const contractAddress = await dynamicNFT.getAddress();
  console.log("✅ Contract deployed to:", contractAddress);

  // Get deployment transaction details
  const deploymentTxHash = dynamicNFT.deploymentTransaction().hash;
  const deploymentReceipt = await ethers.provider.getTransactionReceipt(deploymentTxHash);
  
  console.log("📄 Transaction hash:", deploymentTxHash);
  console.log("⛽ Gas used:", deploymentReceipt.gasUsed.toString());
  console.log("💸 Actual cost:", ethers.formatEther(deploymentReceipt.gasUsed * deploymentReceipt.gasPrice), "ETH");

  // Set up initial configuration
  console.log("\n🔧 Setting up initial configuration...");

  try {
    // Set base URIs for different evolution stages
    const baseURIs = {
      EGG: process.env.EGG_BASE_URI || "https://gateway.pinata.cloud/ipfs/QmEggHash/",
      JUVENILE: process.env.JUVENILE_BASE_URI || "https://gateway.pinata.cloud/ipfs/QmJuvenileHash/",
      ADULT: process.env.ADULT_BASE_URI || "https://gateway.pinata.cloud/ipfs/QmAdultHash/",
      ELDER: process.env.ELDER_BASE_URI || "https://gateway.pinata.cloud/ipfs/QmElderHash/"
    };

    // Evolution stages enum mapping
    const EvolutionStage = {
      EGG: 0,
      JUVENILE: 1,
      ADULT: 2,
      ELDER: 3
    };

    for (const [stageName, stageIndex] of Object.entries(EvolutionStage)) {
      if (baseURIs[stageName]) {
        console.log(`🎨 Setting ${stageName} base URI...`);
        const tx = await dynamicNFT.setStageBaseURI(stageIndex, baseURIs[stageName]);
        await tx.wait();
        console.log(`✅ ${stageName} base URI set successfully`);
      }
    }

    // Mint initial NFTs for testing (if specified)
    const initialMintAmount = parseInt(process.env.INITIAL_MINT_AMOUNT) || 0;
    if (initialMintAmount > 0) {
      console.log(`\n🪙 Minting ${initialMintAmount} initial NFTs...`);
      
      for (let i = 0; i < initialMintAmount; i++) {
        const mintTx = await dynamicNFT.mintDynamicNFT(
          deployerAddress,
          `Genesis NFT #${i + 1}`
        );
        await mintTx.wait();
        console.log(`✅ Minted NFT #${i + 1}`);
      }
    }

  } catch (error) {
    console.log("⚠️  Configuration setup failed:", error.message);
    console.log("💡 You can set these manually after deployment");
  }

  // Verify contract if on supported network
  const network = await ethers.provider.getNetwork();
  const supportedNetworks = ["mainnet", "goerli", "sepolia", "polygon", "mumbai"];
  
  if (supportedNetworks.includes(network.name) && process.env.VERIFY_CONTRACTS === "true") {
    console.log("\n🔍 Verifying contract on block explorer...");
    
    // Wait for a few block confirmations before verification
    console.log("⏳ Waiting for block confirmations...");
    await dynamicNFT.deploymentTransaction().wait(5);
    
    try {
      await verify(contractAddress, []);
      console.log("✅ Contract verified successfully!");
    } catch (error) {
      console.log("❌ Verification failed:", error.message);
      console.log("💡 You can verify manually later using:");
      console.log(`npx hardhat verify --network ${network.name} ${contractAddress}`);
    }
  }

  // Save deployment information
  const deploymentInfo = {
    network: network.name,
    chainId: network.chainId,
    contractAddress: contractAddress,
    deployerAddress: deployerAddress,
    deploymentTxHash: deploymentTxHash,
    blockNumber: deploymentReceipt.blockNumber,
    gasUsed: deploymentReceipt.gasUsed.toString(),
    deploymentCost: ethers.formatEther(deploymentReceipt.gasUsed * deploymentReceipt.gasPrice),
    timestamp: new Date().toISOString(),
    contractName: "DynamicNFTCollectionwithEvolutionMechanics"
  };

  // Write deployment info to file
  const fs = require("fs");
  const path = require("path");
  
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const networkDir = path.join(deploymentsDir, network.name);
  
  // Create directories if they don't exist
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }
  if (!fs.existsSync(networkDir)) {
    fs.mkdirSync(networkDir);
  }
  
  // Save deployment info
  const deploymentPath = path.join(networkDir, "DynamicNFTCollection.json");
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  
  console.log("\n📁 Deployment information saved to:", deploymentPath);

  // Display summary
  console.log("\n" + "=".repeat(80));
  console.log("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
  console.log("=".repeat(80));
  console.log("📋 Summary:");
  console.log("🏷️  Contract Name: DynamicNFTCollectionwithEvolutionMechanics");
  console.log("📍 Contract Address:", contractAddress);
  console.log("🌐 Network:", network.name);
  console.log("🔗 Chain ID:", network.chainId);
  console.log("💰 Total Cost:", ethers.formatEther(deploymentReceipt.gasUsed * deploymentReceipt.gasPrice), "ETH");
  console.log("⛽ Gas Used:", deploymentReceipt.gasUsed.toString());
  
  if (network.name === "mainnet") {
    console.log("🔍 Etherscan:", `https://etherscan.io/address/${contractAddress}`);
  } else if (network.name === "goerli") {
    console.log("🔍 Etherscan:", `https://goerli.etherscan.io/address/${contractAddress}`);
  } else if (network.name === "sepolia") {
    console.log("🔍 Etherscan:", `https://sepolia.etherscan.io/address/${contractAddress}`);
  } else if (network.name === "polygon") {
    console.log("🔍 Polygonscan:", `https://polygonscan.com/address/${contractAddress}`);
  } else if (network.name === "mumbai") {
    console.log("🔍 Polygonscan:", `https://mumbai.polygonscan.com/address/${contractAddress}`);
  }

  console.log("\n📝 Next Steps:");
  console.log("1. Set up metadata URIs for each evolution stage");
  console.log("2. Upload artwork to IPFS and update base URIs");
  console.log("3. Test minting and evolution functionality");
  console.log("4. Set up frontend integration");
  console.log("5. Configure any additional features");
  
  console.log("\n💡 Useful Commands:");
  console.log(`npx hardhat verify --network ${network.name} ${contractAddress}`);
  console.log(`npx hardhat run scripts/mint.js --network ${network.name}`);
  console.log(`npx hardhat run scripts/interact.js --network ${network.name}`);
  
  console.log("=".repeat(80));

  return {
    contract: dynamicNFT,
    address: contractAddress,
    deploymentInfo: deploymentInfo
  };
}

// Error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });

// Export for use in other scripts
module.exports = main;
