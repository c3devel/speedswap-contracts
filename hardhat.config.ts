import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "hardhat-deploy";

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
    }
  },
  networks: {
    ['autobahn-sepolia']: {
      url: 'https://rpc-testnet.autobahn.network/',
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
      chainId: 45045,
      live: true,
      saveDeployments: true,
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          }
        }
      },
    ]
  }
};

export default config;
