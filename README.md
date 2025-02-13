# zkVerify - Powered Defi Stablecoin 
---

This project is a DeFi stablecoin system that leverages zkVerify and zero-knowledge proofs (ZKPs) to enable users to mint stablecoins while proving collateral sufficiency without revealing their health factor. By integrating zkVerify, we ensure privacy-preserving and trustless collateral verification.

---

## Features

- **Zero-Knowledge Collateral Verification**: Users can prove they hold sufficient collateral with the help of Zero-Knowledge Proofs.
- **Trustless Minting Mechanism**: The system mints stablecoins only when ZKPs confirm collateral sufficiency.
- **Chainlink Oracles for Price Feeds**: Ensures reliable and decentralized asset pricing.
- **Unlocking the Power of DeFi with ZKPs**: Leveraging zero-knowledge proofs to ensure privacy, security, and efficiency in stablecoin transactions.

---

## Tech Stack                                              

- **Solidity: Smart contract development.**

- **zkVerify: Blockchain focused on Zero-Knowledge proof verification.**

- **Arbitrum: Smart contracts are deployed on the sepolia arbitrum testnet.**

- **Chainlink Price Oracles: Fetch real-time asset prices.**

- **RiscZero: Generation of Zero-Knowledge Proofs.**

- **Foundry: Smart contract development and testing framework.**

---
## Architecture

The ZKDSC system is built on the Ethereum blockchain and consists of two primary components: the ZKDSC token and the DSCEngine contract.

### ZKDSC Token

The ZKDSC token is a digital currency that represents the stablecoin in our system. It's designed to maintain a 1:1 ratio with the US dollar. The token contract includes functions for creating (minting) and destroying (burning) tokens, which are only accessible by the owner, typically set to be the ZKDSCEngine contract.

### ZKDSCEngine Contract

The ZKDSCEngine contract is the core of the ZKDSC system. It manages the operations related to minting and redeeming ZKDSC, as well as handling the deposit and withdrawal of collateral. The collateral is overcollateralized, meaning the value of collateral is always more than the value of minted ZKDSC. This overcollateralization provides an additional layer of security, ensuring the stability of the ZKDSC token.

## Algorithm

The ZKDSCEngine contract uses an algorithm to calculate a health factor for each user's position. This health factor is a measure of the risk associated with a user's position. If the health factor falls below a certain threshold, the contract triggers a liquidation of the user's position to ensure the system remains overcollateralized.

## Integration with zkVerify
The system uses Risc0 to generate the ZK Proof and the verified proofs are stored immutably on the zkVerify blockchain. These proofs are used by the ZKDSCEngine to verify and check the health factor of the user. Each time the user wants to mint ZKDSC tokens or burn ZKDSC tokens, user has to generate a valid proof for the post account details in prior.

## Integration with Chainlink

The system integrates with Chainlink price feeds to get real-time price information of the collateral tokens. This ensures accurate calculation of the health factor and the collateralization ratio, contributing to the overall stability of the ZKDSC.

## Integration with Arbitrum

The system leverages Arbitrum Chain, reducing gas fees and making verification and stablecoin transactions more efficient and fast.


## Challenges we ran into
1. We faced a lot of issue with the setup of Risc0.
2. Tried setting it up for 4 days but it was not working in one of the laptop's. Finally we wrote the entire code on a single laptop in which it was working.
4. First time working with Rust which itself was a challenge. 
3. Our contract logic was complex which made debugging a pain in the a**. 
---

## Future Enhancements
   - Build a user-friendly frontend for seamless interaction.
   - Multi-collateral support for enhanced stability.
   - Cross-chain stablecoin issuance via Chainlink CCIP.

---

## Use Cases
   - Decentralized Lending Protocols: Lenders can verify a borrower's creditworthiness using zk-proofs.
   - Fast & Cheap Transactions: Compared to traditional banking, stablecoins allow instant, low-cost transactions worldwide.
   - Cross-Border Transactions: People can send money across countries without high transaction fees.
   - Merchant Payments: Businesses accept stablecoins as payments, reducing volatility risks associated with other cryptocurrencies.
   - Lending & Borrowing: Users can lend stablecoins on platforms like Aave to earn interest.
   - Safe Haven from Volatility: Traders convert volatile crypto assets into stablecoins to avoid losses.

---
##  Project Setup
1. Git clone the repository.
2. Downloading all necessary dependencies: 
```shell
$ forge install
```
3. Proof Generation for the HealthFactor:
```shell
$ cd health_factor/
$RISC0_DEV_MODE=0 cargo run --release
```
4. Attestion of the generated proof.json on zkVerify Chain using zkVerifyjs package:
```shell
$ cd proof_verification/
$ node verifyProof.js
```
5. Deploy the ZKDSCEngine file and ZKDecentralizedStableCoin token using the deployed script:
```shell
#for Etheruem Sepolia
$ forge script script/DeployZKDSCEngine.s.sol:DeployZKDSC --rpc_url <sepolia_rpc_url> --private-key <private_key> --verify <etherscan_api_key> --broadcast

#for Arbitrum Sepolia 
$ forge script script/DeployZKDSCEngine.s.sol:DeployZKDSC --rpc_url <arbitrum_rpc_url> --private-key <private_key> --verify <arbiscan_api_key> --broadcast
```
---