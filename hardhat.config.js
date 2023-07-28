const path = require('path');
const envPath = path.join(__dirname, '../../.env');
require('dotenv').config({ path: envPath });

require('hardhat-deploy');
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
let secret = require("./secret");
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	networks: {
		localhost: {
      		gas: 1,
		},
		goerli: {
			url: secret.url, 
			accounts: [secret.key],
			chainId: 5,
			gasPrice: 30000000000,
      		gas: 9000000,
			gasMultiplier: 1.2
		},
		sepolia: {
			url: secret.url, 
			accounts: [secret.key],
			chainId: 11155111,
			gasPrice: 30000000000,
      		gas: 9000000,
			gasMultiplier: 1.2
		},
		ethereum: {
			url: secret.url, 
			accounts: [secret.key],
			chainId: 1,
			gasPrice: 70000000000,
      		gas: "auto",
			gasMultiplier: 1.2
		}
	},
	solidity: {
		compilers: [
			{
				version: "0.8.18",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200
					}
				  }
			}
		],
	},
    paths: {
      sources: "./contracts",
      tests: "./test",
      cache: "./cache",
      artifacts: "./artifacts"
    },
    mocha: {
      timeout: 500000
	},
	etherscan: {
		//apiKey: process.env.BSCSCAN_API_KEY // BSC
		apiKey: process.env.ETHERSCAN_API_KEY, // ETH Mainnet
		// apiKey: process.env.FTMSCAN_API_KEY // Fantom
		// apiKey: process.env.POLYGONSCAN_API_KEY // Polygon
	},

	contractSizer: {
		alphaSort: true,
		runOnCompile: true,
		disambiguatePaths: false,
	}
};