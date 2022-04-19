import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";

import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-contract-sizer";

require("dotenv").config();

export default {
	defaultNetwork: "hardhat",
	networks: {
		hardhat: {
			forking: {
				url: process.env.MAINNET,
				//blockNumber: 13708200,
			},
			gasPrice: 10000,
			initialBaseFeePerGas: 1000
		},
	},
	namedAccounts: {
		deployer: 0,
	},
	solidity: {
		compilers: [{ version: "0.8.13" }, { version: "0.7.4" }, { version: "0.6.12" }, { version: "0.5.17" }],
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN_KEY,
	},
	contractSizer: {
		alphaSort: true,
		disambiguatePaths: false,
		runOnCompile: true,
		strict: true,
	},
} as HardhatUserConfig;
