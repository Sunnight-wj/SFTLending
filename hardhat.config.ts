import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import { loadEnv } from "./utils/EnvLoader";


const { BSCSCAN_API_KEY, DEPLOYER_PRIVATE_KEY } = loadEnv();
const accounts = DEPLOYER_PRIVATE_KEY == undefined ? [] : [DEPLOYER_PRIVATE_KEY];

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
      bscmain: "0x3BBFa3feDbb53323CD2beb754f20bDbb87D04bc1",
      bsctest: "0x49554923b9361e158Fb267B436f843a4f537D53a",
    },
    filTokenAddress: {
      bscmain: "0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153",
      bsctest: "0xCb12e617C17598EDa4ebC2e8a75cb0698feEE829",
    },
    sftTokenAddress: {
      bscmain: "0xF9Dc0A2FB541C29026A798D116B2c6804DA1cAAa",
      bsctest: "0xf1bD68640968C9788B7430218102c368fBBaa194",
    },
    distributorAddress: {
      bscmain: "0x3BBFa3feDbb53323CD2beb754f20bDbb87D04bc1",
      bsctest: "0x49554923b9361e158Fb267B436f843a4f537D53a",
    },
    treasuryAddress: {
      bscmain: "0x3BBFa3feDbb53323CD2beb754f20bDbb87D04bc1",
      bsctest: "0x49554923b9361e158Fb267B436f843a4f537D53a",
    },
    proxyAdminAddress: {
      bscmain: "0x5e549abf8626F1F52393B2Cad3c7e2CC3e89BD8b",
      bsctest: "0xE2925750753e6C3e870B2ba8017837618F2d7602",
    }

    
  },
  defaultNetwork: "hardhat",
  networks: {
    bscmain: {
      url: 'https://bsc-dataseed1.defibit.io/',
      chainId: 56,
      accounts,
    },
    bsctest: {
      url: 'https://bsc-testnet.publicnode.com',
      chainId: 97,
      gasMultiplier: 1.25,
      accounts,
    },
  },

  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      bsc: `${BSCSCAN_API_KEY || ""}`,
      bscTestnet: `${BSCSCAN_API_KEY || ""}`
    },
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ["externalArtifacts/*.json"], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false, // defaults to false
  },
};

export default config;
