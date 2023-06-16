import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
 
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts } = hre;
    const { deployer, distributorAddress, filTokenAddress, sftTokenAddress, treasuryAddress, proxyAdminAddress } = await getNamedAccounts();
    const signer = await ethers.getSigner(deployer);
    
    // deploy SFilToken
    const SFilTokenResult = await deployments.deploy("SFilToken", {
        from: deployer,
        args: []
    });
    console.log(`SFilToken contract address: ${SFilTokenResult.address}`);
    const SFilTokenProxyResult = await deployments.deploy("SFilTokenProxy", {
        from: deployer,
        args: [SFilTokenResult.address, proxyAdminAddress, "0x"],
        contract: "TransparentUpgradeableProxy",
    });
    console.log(`SFilToken Proxy contract address: ${SFilTokenProxyResult.address}`);
    // deploy VariableDebtToken
    const VariableDebtTokenResult = await deployments.deploy("VariableDebtToken", {
        from: deployer,
        args: []
    });
    console.log(`VariableDebtToken contract address: ${VariableDebtTokenResult.address}`);
    const VariableDebtTokenProxyResult = await deployments.deploy("VariableDebtTokenProxy", {
        from: deployer,
        args: [VariableDebtTokenResult.address, proxyAdminAddress, "0x"],
        contract: "TransparentUpgradeableProxy",
    });
    console.log(`VariableDebtToken Proxy contract address: ${VariableDebtTokenProxyResult.address}`);

    // deploy DefaultReserveInterestRateStrategy
    const optimalUtilizationRate = ethers.BigNumber.from("800000000000000000000000000"); // 0.8
    const baseVariableBorrowRate = ethers.BigNumber.from("0");
    const variableRateSlope1 = ethers.BigNumber.from("40000000000000000000000000"); // 0.04
    const variableRateSlope2 = ethers.BigNumber.from("1000000000000000000000000000"); // 1
    const DefaultReserveInterestRateStrategyResult = await deployments.deploy("DefaultReserveInterestRateStrategy", {
        from: deployer,
        args: [optimalUtilizationRate, baseVariableBorrowRate, variableRateSlope1, variableRateSlope2]
    });
    console.log(`DefaultReserveInterestRateStrategy contract address: ${DefaultReserveInterestRateStrategyResult.address}`);
    // deploy ReserveLogic and GenericLogic library
    const ReserveLogicResult = await deployments.deploy("ReserveLogic", { from: deployer });
    console.log(`RerserveLogic library address: ${ReserveLogicResult.address}`);
    const GenericLogicResult = await deployments.deploy("GenericLogic", { from: deployer });
    console.log(`GenericLogic library address: ${GenericLogicResult.address}`);

    // deploy LendingPool
    const LendingPoolResult = await deployments.deploy("LendingPool", {
        from: deployer,
        args: [],
        libraries: {
            "RerserveLogic": ReserveLogicResult.address,
            "GenericLogic": GenericLogicResult.address
        }
    });
    console.log(`LendingPool contract address: ${LendingPoolResult.address}`);
    const LendingPoolProxyResult = await deployments.deploy("LendingPoolProxy", {
        from: deployer,
        args: [LendingPoolResult.address, proxyAdminAddress, "0x"],
        contract: "TransparentUpgradeableProxy",
    });
    console.log(`LendingPool Proxy contract address: ${LendingPoolProxyResult.address}`);
    // initialize SFilToken
    const SFilToken = await ethers.getContractAt("SFilToken", SFilTokenProxyResult.address, signer);
    let tokenName = "SFilToken";
    let tokenSymbol = "sFIL";
    let tx = await SFilToken.initialize(LendingPoolProxyResult.address, treasuryAddress, filTokenAddress, tokenName, tokenSymbol);
    await tx.wait();
    console.log(`SFilToken contract initilize successfully.`);
    // initialize VariableDebtToken
    const VariableDebtToken = await ethers.getContractAt("VariableDebtToken", VariableDebtTokenProxyResult.address, signer);
    tokenName = "SFT variable debt bearing FIL";
    tokenSymbol = "variableDebtFIL";
    VariableDebtToken.initialize(LendingPoolProxyResult.address, tokenName, tokenSymbol);
    console.log(`VariableDebtToken contract initilize successfully.`);
    // initialize LendingPool
    const LendingPool = await ethers.getContractAt("LendingPool", LendingPoolProxyResult.address, signer);
    const reserveFactor = 100; // 10%
    const ltv = 9000; // 90%
    const liquidationThreshold = 9000; // 90%
    tx = await LendingPool.initialize(
        filTokenAddress,
        sftTokenAddress,
        distributorAddress,
        SFilTokenProxyResult.address,
        VariableDebtTokenProxyResult.address,
        DefaultReserveInterestRateStrategyResult.address,
        reserveFactor,
        ltv,
        liquidationThreshold
    );
    await tx.wait();
    console.log(`LendingPool contract initilize successfully.`);
}
 
export default func;
func.tags = ["LendingPool"];