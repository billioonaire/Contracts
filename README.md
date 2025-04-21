# Contracts

This repository contains a suite of Solidity smart contracts. Each contract serves a different purpose, from token creation to NFT minting and permissioned access control.

## Contracts Overview

### 1. `Token.sol`
A custom ERC-20 token with custom launch logic to avoid snipers. This includes a slow increasing maxbuy each block aswell as logic for a 5% transaction tax.


### 2. `Sniper.sol`
Designed to execute snipe-style buy transactions with handling for max buys aswell as potential contract tax. Useful for grabbing tokens during high-demand launches.

**Key Features:**
- Includes logic to avoid max buy/sell traps
- Handles wallet limits

### 3. `MassMinter.sol`
A batch NFT minting utility that allows users to mint multiple NFTs in a single transaction. Useful for promotional drops, giveaways, or scaling mint operations. Also useful for bypassing wallet limits in other contract instances.

**Key Features:**
- Batch minting function
- Ability to execute arbitrary code across hundreds of contracts in a given transaction
- Access-controlled to prevent misuse

### 4. `UnchainedPass.sol`
An ERC-721-based NFT contract for creating Unchained Access Passes. These could be used to grant special permissions, verify identity, or enable gated features.

**Key Features:**
- Fully compliant ERC-721 token
- Minting and burning functions
- metadata and URI handling
