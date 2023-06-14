import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
 
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts } = hre;
    const { deployer, distributorAddress } = await getNamedAccounts();
    const signer = await ethers.getSigner(deployer);

}
 
export default func;
func.tags = ["LendingPool"];