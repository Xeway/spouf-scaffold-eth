// upgrade.js is used to deploy a new version of a contract on the Kovan network

const proxyAddress = "0x9052897901aDAa3007F58613b4461a14a9E8E60c";

async function main() {

    const [deployer] = await hre.ethers.getSigners();
    const accountBalance = await deployer.getBalance();

    console.log("Deploying contract with account: ", deployer.address);
    console.log("Account balance: ", accountBalance.toString());

    const spoufContractFactory = await hre.ethers.getContractFactory("Spouf");
    const spoufContract = await upgrades.upgradeProxy(proxyAddress, spoufContractFactory);

    await spoufContract.deployed();

    console.log("Smart contract's address: ", spoufContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });