//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ZKDecentralizedStableCoin} from "./ZKDecentralizedStableCoin.sol";
import {IZkVerifyAttestation} from "./interfaces/IZKVerify.sol";
/*
 * @title ZKDSCEngine
 * @author SuyashAlphaC & PROWLERx15
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and LINK.
 *
 * Our ZKDSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the ZKDSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming ZKDSC, as well as depositing and withdrawing collateral.
 */

contract ZKDSCEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error ZKDSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error ZKDSCEngine__NeedsMoreThanZero();
    error ZKDSCEngine__TokenNotAllowed(address token);
    error ZKDSCEngine__TransferFailed();
    error ZKDSCEngine__BreaksHealthFactor(uint128 healthFactorValue);
    error ZKDSCEngine__MintFailed();
    error ZKDSCEngine__HealthFactorOk();
    error ZKDSCEngine__HealthFactorNotImproved();

    ///////////////////
    // Types
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////
    // State Variables
    ///////////////////

    // zkVerify contract
    address public zkVerify;

    // vkey for our circuit
    bytes32 public vkey;

    // version hash
    bytes32 public vhash;

    bytes32 public constant PROVING_SYSTEM_ID = keccak256(abi.encodePacked("risc0"));

    ZKDecentralizedStableCoin private immutable i_ZKdsc;

    uint128 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint128 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint128 private constant LIQUIDATION_PRECISION = 100;
    uint128 private constant MIN_HEALTH_FACTOR = 1e18;
    uint128 private constant PRECISION = 1e18;
    uint128 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint128 private constant FEED_PRECISION = 1e8;

    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint128 amount)) private s_collateralDeposited;
    /// @dev Amount of ZKDSC minted by user
    mapping(address user => uint128 amount) private s_ZKDSCMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint128 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint128 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint128 amount) {
        if (amount == 0) {
            revert ZKDSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert ZKDSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address ZKdscAddress,
        address _zkverify
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert ZKDSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint128 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_ZKdsc = ZKDecentralizedStableCoin(ZKdscAddress);
        vhash = bytes32(0x5f39e7751602fc8dbc1055078b61e2704565e3271312744119505ab26605a942);
        zkVerify = _zkverify;
    }

    ///////////////////
    // External Functions
    ///////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountZKDscToMint: The amount of ZKDSC you want to mint
     * @notice This function will deposit your collateral and mint ZKDSC in one transaction
     */
    function depositCollateralAndMintZKDsc(
        address tokenCollateralAddress,
        uint128 amountCollateral,
        uint128 amountZKDscToMint,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintZKDsc(amountZKDscToMint, _hash, _attestationId, _merklePath, _leafCount, _index);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're withdrawing
     * @param amountCollateral: The amount of collateral you're withdrawing
     * @param amountZKDscToBurn: The amount of ZKDSC you want to burn
     * @notice This function will withdraw your collateral and burn ZKDSC in one transaction
     */
    function redeemCollateralForZKDsc(
        address tokenCollateralAddress,
        uint128 amountCollateral,
        uint128 amountZKDscToBurn,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        _burnZKDsc(amountZKDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender, _hash, _attestationId, _merklePath, _leafCount, _index);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have ZKDSC minted, you will not be able to redeem until you burn your ZKDSC
     */
    function redeemCollateral(
        address tokenCollateralAddress,
        uint128 amountCollateral,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) external moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress) {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender, _hash, _attestationId, _merklePath, _leafCount, _index);
    }

    /*
     * @notice careful! You'll burn your ZKDSC here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * your ZKDSC but keep your collateral in.
     */
    function burnZKDsc(
        uint128 amount,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) external moreThanZero(amount) {
        _burnZKDsc(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender, _hash, _attestationId, _merklePath, _leafCount, _index); // I don't think this would ever hit...
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your ZKDSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of ZKDSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     */
    function liquidate(
        address collateral,
        address user,
        uint128 debtToCover,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) external isAllowedToken(collateral) moreThanZero(debtToCover) nonReentrant {
        uint128 startingUserHealthFactor = _healthFactor(user, _hash, _attestationId, _merklePath, _leafCount, _index);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert ZKDSCEngine__HealthFactorOk();
        }
        uint128 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        uint128 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn ZKDSC equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnZKDsc(debtToCover, user, msg.sender);

        uint128 endingUserHealthFactor = _healthFactor(user, _hash, _attestationId, _merklePath, _leafCount, _index);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert ZKDSCEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender, _hash, _attestationId, _merklePath, _leafCount, _index);
    }

    ///////////////////
    // Public Functions
    ///////////////////
    /*
     * @param amountZKDscToMint: The amount of ZKDSC you want to mint
     * You can only mint ZKDSC if you have enough collateral
     */
    function mintZKDsc(
        uint128 amountZKDscToMint,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) public moreThanZero(amountZKDscToMint) nonReentrant {
        revertIfHealthFactorIsBroken(msg.sender, _hash, _attestationId, _merklePath, _leafCount, _index);
        s_ZKDSCMinted[msg.sender] += amountZKDscToMint;
        bool minted = i_ZKdsc.mint(msg.sender, amountZKDscToMint);

        if (minted != true) {
            revert ZKDSCEngine__MintFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint128 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert ZKDSCEngine__TransferFailed();
        }
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(address tokenCollateralAddress, uint128 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert ZKDSCEngine__TransferFailed();
        }
    }

    function _burnZKDsc(uint128 amountZKDscToBurn, address onBehalfOf, address ZKdscFrom) private {
        s_ZKDSCMinted[onBehalfOf] -= amountZKDscToBurn;

        bool success = i_ZKdsc.transferFrom(ZKdscFrom, address(this), amountZKDscToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert ZKDSCEngine__TransferFailed();
        }
        i_ZKdsc.burn(amountZKDscToBurn);
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint128 totalZKDscMinted, uint128 collateralValueInUsd)
    {
        totalZKDscMinted = s_ZKDSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(
        address user,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) private returns (uint128) {
        (uint128 totalZKDscMinted, uint128 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(
            totalZKDscMinted, collateralValueInUsd, _hash, _attestationId, _merklePath, _leafCount, _index
        );
    }

    function _getUsdValue(address token, uint128 amount) private view returns (uint128) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint128(((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION);
    }

    function parseZKParams(bytes32 _vkey) public {
        vkey = _vkey;
    }

    function getLeaf(bytes32 hash) public view returns (bytes32) {
        return keccak256(abi.encodePacked(PROVING_SYSTEM_ID, vkey, vhash, keccak256(abi.encodePacked(hash))));
    }

    function _calculateHealthFactor(
        uint128 totalZKDscMinted,
        uint128 collateralValueInUsd,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) internal returns (uint128) {
        // Calculate expected health factor
        if (totalZKDscMinted == 0) return type(uint128).max;

        uint128 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint128 expectedHealthFactor = (collateralAdjustedForThreshold * PRECISION) / totalZKDscMinted;

        bytes memory expectedPublicInputs =
            abi.encodePacked(uint128(expectedHealthFactor), uint128(collateralValueInUsd), uint128(totalZKDscMinted));

        // Verify the proof matches our calculated values
        _verifyHealthFactorProof(_hash, _attestationId, _merklePath, _leafCount, _index, expectedPublicInputs);
        return expectedHealthFactor;
    }

    function _verifyHealthFactorProof(
        bytes memory proofPublicInputs,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index,
        bytes memory expectedPublicInputs
    ) public {
        require(proofPublicInputs.length == 96, "Invalid public inputs length");
        require(keccak256(proofPublicInputs) == keccak256(expectedPublicInputs), "Public inputs mismatch");

        bytes32 leaf =
            keccak256(abi.encodePacked(PROVING_SYSTEM_ID, vkey, vhash, keccak256(abi.encodePacked(proofPublicInputs))));

        require(
            IZkVerifyAttestation(zkVerify).verifyProofAttestation(_attestationId, leaf, _merklePath, _leafCount, _index),
            "Invalid proof"
        );
    }

    function revertIfHealthFactorIsBroken(
        address user,
        bytes memory _hash,
        uint128 _attestationId,
        bytes32[] calldata _merklePath,
        uint128 _leafCount,
        uint128 _index
    ) internal {
        uint128 userHealthFactor = _healthFactor(user, _hash, _attestationId, _merklePath, _leafCount, _index);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert ZKDSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function getAccountCollateralValue(address user) private view returns (uint128 totalCollateralValueInUsd) {
        for (uint128 index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint128 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////

    function getUsdValue(
        address token,
        uint128 amount // in WEI
    ) external view returns (uint128) {
        return _getUsdValue(token, amount);
    }

    function getTokenAmountFromUsd(address token, uint128 usdAmountInWei) public view returns (uint128) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint128(((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION)));
    }

    function getPrecision() external pure returns (uint128) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint128) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint128) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint128) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint128) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint128) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getZKDsc() external view returns (address) {
        return address(i_ZKdsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }
}
