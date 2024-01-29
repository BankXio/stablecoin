# BankX and XSD code base
### These are the main files which include most of the functionality associated with this codebase:

1. **BankXToken.sol**: The utility coin based on the ERC20 template.

2. **XSDStablecoin.sol**: The stablecoin based on the ERC20 template.

3. **PIDController.sol**: Keeps the price of XSD in check and triggers incentives in when there is a deficit.

4. **Router.sol**: A peripheral contract based on the UniswapV2Router that can be used to interact with the BankX and XSD liquidity pools.

5. **BankXWETH/XSDWETHpool.sol**: The liquidity pool contracts based on the UniswapV2pair contracts.

6. **CollateralPool.sol**: The collateral pool from which users can mint XSD and redeem interest for doing so. Interest calulations are done in the CollateralPoolLibrary contract.

7. **RewardManager.sol**: The reward manager contract is responsible for handling the liquidity providing process for the collateral and liquidity pools.

## Compiling
Use the following command to compile the code: 
```
npx hardhat compile
```

## Testing

Similarly you can use 'npx hardhat test' command to run tests. ~~Keep in mind that the test will fail if not connected to an appropriate test net with Chainlink addresses.~~ Chainlink does not support the Sepolia testnet.
After you've installed the necessary npm packages via npm i, you can run the Collateral Pool minting tests on the Sepolia Testnet through the command: 
```
npx hardhat test test/XSDPool.js --network sepolia
```

## Deployment
You can deploy all the contracts to the Sepolia test network using the deploy script via the command:
```
npx hardhat run scripts/deploy_test.js --network sepolia

```

## Current deployed addresses:

🧐 Ethereum Contract Addresses:

BankxToken address:   0x13e636cbfd6a7d33a8df7ebbf42f63adc9bb592a
XSDToken address:   0x75Cae30025A514b7AE069917E132Cc99762A0e16
BankX Pool:  0x2147F5c02c2869E8C2d8F86471d3d7500355d698
XSD Pool:  0x53f51fcDf06946AafE25F14d2f1C9B66E71Ca683
Collateral Pool:  0xeeA52F6587F788cc12d0b5a28c48e61866c076F0
PID:  0xAbAc1C04408Cb6509BC9340e6b033c17F161Ef9e
Reward Manager:  0x93Abe713002526D4cE708f890139f19313012f95
Router: 0x59cA927Ae4c900dC8091515191E39B010bec1118
Arbitrage: 0x58421507d10A4c57a761E8AAd5382D5564A682F5

CD address:  0xc74Ff6Db79D466087BfEe53980eeCB9A5f3c2640
BankXNFT address:  0xD6e2c209a1227F7918cf62acB26BBb213bAc4d17
NFTBonus address:  0xCa6D501Af96Fff556140CEd968C856BBa2d111CB

Claim App:  0xC5d8Dc66A6d36CF66Bb6eB3a404C1A63FA6D7939


🧐 BNB Contract Addresses:

BankXToken address:  0x4d369BD339709021267E92702A9E4cE30be85706
XSDToken address:  0x39400E67820c88A9D67F4F9c1fbf86f3D688e9F6
BankX Pool address:  0xfa0870077A65dBFde9052ad16B04C3e1A885CE2d
XSD Pool address:  0x8A4e0e2A778dF8cE4EA5D5108FFfE690CC9Ae07a
Collateral Pool address:  0x55A75059065296a5a8cdfadCF6945ed2cC5B8eC6
PID controller address:  0x6683FFdA5267e1F7E9Bf6790849a4eCdD63ed134
Reward Manager:  0xc8d2cdE3fc9690Dffa365a2c7e5c6bc8961893b8
Router address:  0xEf8ef7e50Dc49AAe7beEb3D0004CB196F5a850C5
Arbitrage:  0x79471BA0cCA010D8623f896C593d546691E53e5e

CD address:  0xED024d771261D765B9Dc7b0947ef271ea006248F
BankXNFT address:  0x11214D41a85306f725cdd9A318993b122bAa6DFe
NFTBonus address:  0x369B83fe557Ef815572A340F5275D8D764615D15

Claim App:  0x9c261e1556694c88f5950b40593724E613D3512f















