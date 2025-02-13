// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address linkUsdPriceFeed;
        address weth;
        address link;
        uint256 deployerKey;
        address zkVerifyAddress;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant LINK_USD_PRICE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 421614) {
            activeNetworkConfig = getArbitrumSepoliaConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            linkUsdPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            zkVerifyAddress: address(0x209f82A06172a8d96CF2c95aD8c42316E80695c1)
        });
    }

    function getArbitrumSepoliaConfig() public view returns (NetworkConfig memory arbitrumSepoliaConfig) {
        arbitrumSepoliaConfig = NetworkConfig({
            wethUsdPriceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165, // ETH / USD
            linkUsdPriceFeed: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,
            weth: 0x50deF747B53D19A2592376E2fa3e29416321DaBc,
            link: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            deployerKey: vm.envUint("PRIVATE_KEY"),
            zkVerifyAddress: address(0x82941a739E74eBFaC72D0d0f8E81B1Dac2f586D5)
        });
    }
}
