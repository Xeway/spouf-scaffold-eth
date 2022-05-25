// deploy/00_deploy_your_contract.js

const fs = require("fs");
const { abi } = require("../artifacts/contracts/Spouf.sol/Spouf.json");

let obj = {
  42: {
    kovan: {
      name: "kovan",
      chainId: "42",
      contracts: {}
    }
  }
}

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const [deployer] = await hre.ethers.getSigners();
  const accountBalance = await deployer.getBalance();

  console.log("Deploying proxy contract with account: ", deployer.address);
  console.log("Account balance: ", accountBalance.toString());

  const proxyContractFactory = await hre.ethers.getContractFactory("Spouf");
  const proxyContract = await upgrades.deployProxy(proxyContractFactory, ["0xb7a4F3E9097C08dA09517b5aB877F7a917224ede", "0xa36085F69e2889c224210F603D836748e7dC0088"], { initializer: 'initialize' });

  await proxyContract.deployed();

  console.log("Proxy's address: ", proxyContract.address);

  obj["42"].kovan.contracts = {...obj["42"].kovan.contracts, Spouf: {
    address: proxyContract.address,
    abi: abi
  }};

  console.log(obj);

  fs.writeFileSync("../react-app/src/contracts/hardhat_contracts.json", JSON.stringify(obj, null, 3), (err) => {
    if (err) {
      console.log("Error to write file", err);
      return;
    }
    console.log("File created");
  });

  // Verify from the command line by running `yarn verify`

  // You can also Verify your contracts with Etherscan here...
  // You don't want to verify on localhost
  // try {
  //   if (chainId !== localChainId) {
  //     await run("verify:verify", {
  //       address: YourContract.address,
  //       contract: "contracts/YourContract.sol:YourContract",
  //       constructorArguments: [],
  //     });
  //   }
  // } catch (error) {
  //   console.error(error);
  // }
};
module.exports.tags = ["YourContract"];
