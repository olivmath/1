// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/solady/src/auth/Ownable.sol";

contract OracleConnector is Ownable {
    event MetricsUpdated(uint256 campaignId, uint256 likes, uint256 views);

    address public campaignManager;

    mapping(address => bool) public authorizedOracles;

    modifier onlyOracle() {
        require(
            authorizedOracles[msg.sender],
            "OracleConnector: caller is not an authorized oracle"
        );
        _;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setCampaignManager(address _campaignManager) external onlyOwner {
        require(
            _campaignManager != address(0),
            "OracleConnector: invalid campaign manager address"
        );
        campaignManager = _campaignManager;
    }

    function addOracle(address oracle) external onlyOwner {
        require(
            oracle != address(0),
            "OracleConnector: invalid oracle address"
        );
        authorizedOracles[oracle] = true;
    }

    function removeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = false;
    }

    function updateCampaignMetrics(
        bytes4 campaignId,
        uint256 likes,
        uint256 views
    ) external onlyOracle {
        require(
            campaignManager != address(0),
            "OracleConnector: campaign manager not set"
        );
        (bool success, bytes memory data) = campaignManager.call(
            abi.encodeWithSignature(
                "updateMetrics(bytes4,uint256,uint256)",
                campaignId,
                likes,
                views
            )
        );
        require(success, "OracleConnector: failed to update metrics");
        emit MetricsUpdated(uint256(bytes32(campaignId)), likes, views);
    }
}
