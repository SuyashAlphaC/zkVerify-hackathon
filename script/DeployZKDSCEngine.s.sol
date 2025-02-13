// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {ZKDSCEngine} from "../src/ZKDSCEngine.sol";
import {ZKDecentralizedStableCoin} from "../src/ZKDecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DeployZKDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (ZKDSCEngine, ZKDecentralizedStableCoin, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address linkUsdPriceFeed,
            address weth,
            address link,
            uint256 deployerKey,
            address zkVerify
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, link];
        priceFeedAddresses = [wethUsdPriceFeed, linkUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        // Deploy ZKDecentralizedStableCoin
        ZKDecentralizedStableCoin ZKdsc = new ZKDecentralizedStableCoin();

        // Deploy ZKDSCEngine with ZK parameters
        ZKDSCEngine ZKdscEngine = new ZKDSCEngine(tokenAddresses, priceFeedAddresses, address(ZKdsc), zkVerify);

        // Transfer ownership of ZKDSC to ZKDSCEngine
        ZKdsc.transferOwnership(address(ZKdscEngine));

        vm.stopBroadcast();

        return (ZKdscEngine, ZKdsc, helperConfig);
    }
}
