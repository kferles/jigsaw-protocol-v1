// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson as StdJson } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { DeployGenesisOracle } from "./01_DeployGenesisOracle.s.sol";
import { DeployManager } from "./02_DeployManager.s.sol";
import { DeployJUSD } from "./03_DeployJUSD.s.sol";
import { DeployManagers } from "./04_DeployManagers.s.sol";
import { DeployReceiptToken } from "./05_DeployReceiptToken.s.sol";
import { DeployChronicleOracleFactory } from "./06_DeployChronicleOracleFactory.s.sol";
import { DeployRegistries } from "./07_DeployRegistries.s.sol";
import { DeployUniswapV3Oracle } from "./08_DeployUniswapV3Oracle.s.sol";

import { Manager } from "../../src/Manager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { HoldingManager } from "../../src/HoldingManager.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ChronicleOracleFactory } from "../../src/oracles/chronicle/ChronicleOracleFactory.sol";
import { ChronicleOracle } from "../../src/oracles/chronicle/ChronicleOracle.sol";
import { UniswapV3Oracle } from "../../src/oracles/uniswap/UniswapV3Oracle.sol";

/// @notice Deploys the entire protocol on a local Anvil node.
contract DeployProtocol is Script {
    using StdJson for string;

    string internal constant COMMON_CONFIG_PATH = "./deployment-config/00_CommonConfig.json";
    string internal constant MANAGER_CONFIG_PATH = "./deployment-config/01_ManagerConfig.json";
    string internal constant MANAGERS_CONFIG_PATH = "./deployment-config/03_ManagersConfig.json";
    string internal constant UNISWAPV3_CONFIG_PATH = "./deployment-config/04_UniswapV3OracleConfig.json";

    function run() external returns (
        Manager manager,
        JigsawUSD jUSD,
        HoldingManager holdingManager,
        LiquidationManager liquidationManager,
        StablesManager stablesManager,
        StrategyManager strategyManager,
        SwapManager swapManager,
        ReceiptTokenFactory receiptTokenFactory,
        ReceiptToken receiptToken,
        ChronicleOracleFactory chronicleOracleFactory,
        ChronicleOracle chronicleOracle,
        address[] memory registries,
        UniswapV3Oracle jUsdUniswapV3Oracle
    ) {
        address initialOwner = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy the initial jUSD genesis oracle
        DeployGenesisOracle genesisScript = new DeployGenesisOracle();
        genesisScript.run();

        // Persist owner and other config values for subsequent scripts
        Strings.toHexString(uint160(initialOwner), 20).write(COMMON_CONFIG_PATH, ".INITIAL_OWNER");
        // default WETH address on mainnet
        Strings.toHexString(uint160(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 20).write(MANAGER_CONFIG_PATH, ".WETH");
        Strings.toHexString(uint256(bytes32("")), 32).write(MANAGER_CONFIG_PATH, ".JUSD_OracleData");

        // Deploy Manager
        DeployManager managerScript = new DeployManager();
        manager = managerScript.run();

        // Deploy jUSD
        DeployJUSD jUsdScript = new DeployJUSD();
        jUSD = jUsdScript.run();

        // Deploy managers
        DeployManagers managersScript = new DeployManagers();
        (
            holdingManager,
            liquidationManager,
            stablesManager,
            strategyManager,
            swapManager
        ) = managersScript.run();

        // Deploy ChronicleOracleFactory and reference implementation
        DeployChronicleOracleFactory chronicleFactoryScript = new DeployChronicleOracleFactory();
        (chronicleOracleFactory, chronicleOracle) = chronicleFactoryScript.run();

        // Deploy ReceiptTokenFactory and reference implementation
        DeployReceiptToken receiptScript = new DeployReceiptToken();
        (receiptTokenFactory, receiptToken) = receiptScript.run();

        // Deploy registries
        DeployRegistries registriesScript = new DeployRegistries();
        registries = registriesScript.run();

        // Deploy Uniswap oracle
        DeployUniswapV3Oracle uniswapOracleScript = new DeployUniswapV3Oracle();
        jUsdUniswapV3Oracle = uniswapOracleScript.run();
    }
}
