// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

contract PaymentVault is Ownable {
    using SafeTransferLib for address;
    
    address public immutable usdcToken;
    
    address public campaignManager;
    
    mapping(address => uint256) public pendingPayments;
    
    event FundsDeposited(uint256 campaignId, address brand, uint256 amount);
    event PaymentReleased(uint256 campaignId, address creator, uint256 amount);
    event PaymentWithdrawn(address creator, uint256 amount);
    
    modifier onlyCampaignManager() {
        require(msg.sender == campaignManager, "PaymentVault: caller is not the campaign manager");
        _;
    }
    
    constructor(address _usdcToken) {
        require(_usdcToken != address(0), "PaymentVault: invalid USDC token address");
        usdcToken = _usdcToken;
        _initializeOwner(msg.sender);
    }
    
    function setCampaignManager(address _campaignManager) external onlyOwner {
        require(_campaignManager != address(0), "PaymentVault: invalid campaign manager address");
        campaignManager = _campaignManager;
    }
    
    function depositFunds(bytes4 campaignId, address brand, uint256 amount) external onlyCampaignManager {
        require(amount > 0, "PaymentVault: amount must be greater than zero");
        SafeTransferLib.safeTransferFrom(usdcToken, brand, address(this), amount);
        emit FundsDeposited(uint256(bytes32(campaignId)), brand, amount);
    }
    
    function releasePayment(bytes4 campaignId, address creator, uint256 amount) external onlyCampaignManager {
        require(creator != address(0), "PaymentVault: invalid creator address");
        require(amount > 0, "PaymentVault: amount must be greater than zero");
        pendingPayments[creator] += amount;
        emit PaymentReleased(uint256(bytes32(campaignId)), creator, amount);
    }
    
    function withdrawPayment() external {
        address creator = msg.sender;
        uint256 amount = pendingPayments[creator];
        require(amount > 0, "PaymentVault: no pending payments");
        pendingPayments[creator] = 0;
        SafeTransferLib.safeTransfer(usdcToken, creator, amount);
        emit PaymentWithdrawn(creator, amount);
    }
    
    function getPendingPayment(address creator) external view returns (uint256) {
        return pendingPayments[creator];
    }
}