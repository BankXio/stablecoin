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
These contracts can be found on the Sepolia Testnet:

BankXToken address 0x5286D300aBe7597d849B181c852Eb43c85fe6B10

XSDToken address 0xed9a09075FF122A621D5905A907fC895C33c46fB

BankXPool address 0x3B503A3aA75D889e83c19b4e68FffE48C003e5bf

XSDPool address 0x0D20B8fBD9F892693FCE17107Cf2940cd9F331D2

CollateralPool address 0xac105F27fAAb047852E54694D6858CF9D3277f67

PID controller address 0xA2489F83FdAF771A081377B226d93C4f6C62171a

Reward Manager 0xF22FF542e57B47Cd423D414a13B8A47ca769404E

Router address 0xC2Ee1A266B1488ce9Eb2a661fE531e8Fee3471D3

Arbitrage: 0xE5A072d889971671ecaD0986A3316605d34d097d

















