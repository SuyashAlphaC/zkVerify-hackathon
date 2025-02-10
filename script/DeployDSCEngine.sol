// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DeployDSC is Script {
    // Deployment parameters struct
    struct ZKParams {
        bytes32 vkey;
        bytes32 vhash;
        address zkVerify;
    }

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    ZKParams public zkParams;
    bytes32 leaf = 0x6ff131fc86664ee5770f5819f6ab3ef586e12d826d41b8a6547b68f11e7e36d2;
    uint256 attestationId = 38652;

    function run() external returns (DSCEngine, DecentralizedStableCoin, HelperConfig) {
        // Parse ZK verification parameters from files
        zkParams = parseZKParams();

        // Deploy helper config first to get network-specific addresses
        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        // Setup token and price feed arrays
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        // Deploy DecentralizedStableCoin
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();

        // Deploy DSCEngine with ZK parameters
        DSCEngine dscEngine = new DSCEngine(
            tokenAddresses, priceFeedAddresses, address(dsc), zkParams.zkVerify, zkParams.vkey, zkParams.vhash
        );

        // Transfer ownership of DSC to DSCEngine
        dsc.transferOwnership(address(dscEngine));

        vm.stopBroadcast();

        return (dscEngine, dsc, helperConfig);
    }

    function parseZKParams() internal pure returns (ZKParams memory) {
        bytes32 vkey = bytes32(0xe894a06e6a7440657520bd132c35e1aace4f5981ed348bfdd4c936b6ee22918b);
        bytes32 vhash = bytes32(0x5f39e7751602fc8dbc1055078b61e2704565e3271312744119505ab26605a942);

        address zkVerify = address(0x209f82A06172a8d96CF2c95aD8c42316E80695c1);

        return ZKParams({vkey: vkey, vhash: vhash, zkVerify: zkVerify});
    }
}
