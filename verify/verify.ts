import hre from "hardhat";

type TDeployment = {
  address: string;
  args: string[];
};

async function main() {
  const networkName = hre.network.name;

  //just change this to verify a single contract
  const contractName = "LendingPool";
  const { address, args } = (await import(`../deployments/${networkName}/${contractName}.json`)) as TDeployment;
  //{ address, args }
  await hre.run("verify:verify", {
    address: address,
    constructorArguments: args,
    // contract: "contracts/lendingpool/logic/ReserveLogic.sol:ReserveLogic",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
