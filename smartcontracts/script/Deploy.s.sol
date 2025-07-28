// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {CampaignManager} from "../src/CampaignManager.sol";
import {OracleConnector} from "../src/OracleConnector.sol";
import {PaymentVault} from "../src/PaymentVault.sol";
import {USDC} from "../src/USDC.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {        
        // Inicia a transmissão das transações
        vm.startBroadcast();
        
        // 1. Deploy do token USDC (mock)
        USDC usdc = new USDC();
        console.log("USDC deployed at:", address(usdc));
        
        // 2. Deploy do PaymentVault
        PaymentVault paymentVault = new PaymentVault(address(usdc));
        console.log("PaymentVault deployed at:", address(paymentVault));
        
        // 3. Deploy do CampaignManager
        CampaignManager campaignManager = new CampaignManager(address(paymentVault));
        console.log("CampaignManager deployed at:", address(campaignManager));
        
        // 4. Deploy do OracleConnector
        OracleConnector oracleConnector = new OracleConnector();
        console.log("OracleConnector deployed at:", address(oracleConnector));
        
        // 5. Configuração das conexões entre contratos
        
        // Configura o CampaignManager no PaymentVault
        paymentVault.setCampaignManager(address(campaignManager));
        console.log("PaymentVault configured with CampaignManager");
        
        // Configura o OracleConnector no CampaignManager
        campaignManager.setOracleConnector(address(oracleConnector));
        console.log("CampaignManager configured with OracleConnector");
        
        // Configura o CampaignManager no OracleConnector
        oracleConnector.setCampaignManager(address(campaignManager));
        console.log("OracleConnector configured with CampaignManager");
        
        // Adiciona o endereço do deployer como um oráculo autorizado
        oracleConnector.addOracle(msg.sender);
        console.log("Added deployer as authorized oracle");
        
        // Finaliza a transmissão das transações
        vm.stopBroadcast();
        
        console.log("Deployment completed successfully");
    }
}