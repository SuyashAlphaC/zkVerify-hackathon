// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title ZKDecentralizedStableCoin
 * @author SuyashAlphaC & PROWLERx15
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
* This is the contract meant to be owned by ZKDSCEngine. It is a ERC20 token that can be minted and burned by the
ZKDSCEngine smart contract.
 */
contract ZKDecentralizedStableCoin is ERC20Burnable, Ownable {
    error ZKDecentralizedStableCoin__AmountMustBeMoreThanZero();
    error ZKDecentralizedStableCoin__BurnAmountExceedsBalance();
    error ZKDecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("ZKDecentralizedStableCoin", "ZKDSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert ZKDecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert ZKDecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert ZKDecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert ZKDecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
