// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {PaymentVault} from "./PaymentVault.sol";
import {OracleConnector} from "./OracleConnector.sol";

contract CampaignManager is Ownable {
    struct Campaign {
        address brand;
        address creator;
        uint256 totalValue;
        uint256 deadline;
        uint256 targetLikes;
        uint256 targetViews;
        uint256 currentLikes;
        uint256 currentViews;
        uint256 releasedAmount;
        CampaignStatus status;
    }
    
    enum CampaignStatus {
        Created,
        Active,
        Completed,
        Cancelled,
        Expired
    }
    
    uint256 public campaignCounter;
    
    mapping(bytes4 id => Campaign) public campaigns;
    
    PaymentVault public paymentVault;
    
    address public oracleConnector;
    
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed brand,
        address indexed creator,
        uint256 totalValue,
        uint256 deadline,
        uint256 targetLikes,
        uint256 targetViews
    );
    event CampaignStarted(uint256 indexed campaignId);
    event CampaignCompleted(uint256 indexed campaignId);
    event CampaignCancelled(uint256 indexed campaignId);
    event CampaignExpired(uint256 indexed campaignId);
    event MetricsUpdated(uint256 indexed campaignId, uint256 likes, uint256 views);
    event MilestoneAchieved(uint256 indexed campaignId, uint256 amount);
    
    modifier onlyOracle() {
        require(msg.sender == oracleConnector, "CampaignManager: caller is not the oracle connector");
        _;
    }
    
    modifier onlyBrand(bytes4 campaignId) {
        require(campaigns[campaignId].brand == msg.sender, "CampaignManager: caller is not the brand");
        _;
    }
    
    constructor(address _paymentVault) {
        require(_paymentVault != address(0), "CampaignManager: invalid payment vault address");
        paymentVault = PaymentVault(_paymentVault);
        _initializeOwner(msg.sender);
    }
    
    function setOracleConnector(address _oracleConnector) external onlyOwner {
        require(_oracleConnector != address(0), "CampaignManager: invalid oracle connector address");
        oracleConnector = _oracleConnector;
    }
    
    function createCampaign(
        bytes4 campaignId,
        uint256 totalValue,
        uint256 durationDays,
        uint256 targetLikes,
        uint256 targetViews
    ) external {
        require(campaigns[campaignId].creator == address(0), "CampaignManager: campaign ID already exists");
        require(totalValue > 0, "CampaignManager: total value must be greater than zero");
        require(durationDays > 0, "CampaignManager: duration must be greater than zero");
        require(targetLikes > 0 || targetViews > 0, "CampaignManager: at least one target metric must be set");
        
        campaignCounter++;
        uint256 deadline = block.timestamp + (durationDays * 1 days);
        
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            brand: address(0),
            totalValue: totalValue,
            deadline: deadline,
            targetLikes: targetLikes,
            targetViews: targetViews,
            currentLikes: 0,
            currentViews: 0,
            releasedAmount: 0,
            status: CampaignStatus.Created
        });
        
        emit CampaignCreated(
            uint256(bytes32(campaignId)),
            address(0),
            msg.sender,
            totalValue,
            deadline,
            targetLikes,
            targetViews
        );
    }
    
    function startCampaign(bytes4 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.status == CampaignStatus.Created, "CampaignManager: campaign is not in created state");
        require(block.timestamp < campaign.deadline, "CampaignManager: campaign deadline has passed");
        require(campaign.brand == address(0), "CampaignManager: brand already set");
        
        IERC20 usdc = IERC20(paymentVault.usdcToken());
        require(
            usdc.allowance(msg.sender, address(paymentVault)) >= campaign.totalValue,
            "CampaignManager: insufficient USDC allowance"
        );
        
        paymentVault.depositFunds(campaignId, msg.sender, campaign.totalValue);
        
        campaign.status = CampaignStatus.Active;
        campaign.brand = msg.sender;
        
        emit CampaignStarted(uint256(bytes32(campaignId)));
    }
    
    function updateMetrics(bytes4 campaignId, uint256 likes, uint256 views) external onlyOracle {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.status == CampaignStatus.Active, "CampaignManager: campaign is not active");
        require(block.timestamp <= campaign.deadline, "CampaignManager: campaign has expired");
        
        campaign.currentLikes = likes;
        campaign.currentViews = views;
        
        emit MetricsUpdated(uint256(bytes32(campaignId)), likes, views);
        
        checkMilestones(campaignId);
        
        if ((campaign.targetLikes > 0 && likes >= campaign.targetLikes) && 
            (campaign.targetViews > 0 && views >= campaign.targetViews)) {
            completeCampaign(campaignId);
        }
    }
    
    function checkMilestones(bytes4 campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        
        uint256 likesProgress = campaign.targetLikes > 0 
            ? (campaign.currentLikes * 100) / campaign.targetLikes 
            : 0;
            
        uint256 viewsProgress = campaign.targetViews > 0 
            ? (campaign.currentViews * 100) / campaign.targetViews 
            : 0;
            
        uint256 overallProgress;
        if (campaign.targetLikes > 0 && campaign.targetViews > 0) {
            overallProgress = (likesProgress + viewsProgress) / 2;
        } else if (campaign.targetLikes > 0) {
            overallProgress = likesProgress;
        } else {
            overallProgress = viewsProgress;
        }
        
        uint256[] memory milestoneThresholds = new uint256[](4);
        milestoneThresholds[0] = 25;
        milestoneThresholds[1] = 50;
        milestoneThresholds[2] = 75;
        milestoneThresholds[3] = 100;
        
        uint256 valuePerMilestone = campaign.totalValue / 4;
        
        for (uint256 i = 0; i < milestoneThresholds.length; i++) {
            uint256 milestonePayment = (i + 1) * valuePerMilestone;
            if (overallProgress >= milestoneThresholds[i] && campaign.releasedAmount < milestonePayment) {
                uint256 paymentAmount = milestonePayment - campaign.releasedAmount;
                campaign.releasedAmount = milestonePayment;
                paymentVault.releasePayment(campaignId, campaign.creator, paymentAmount);
                emit MilestoneAchieved(uint256(bytes32(campaignId)), paymentAmount);
            }
        }
    }
    
    function completeCampaign(bytes4 campaignId) internal {
        Campaign storage campaign = campaigns[campaignId];
        campaign.status = CampaignStatus.Completed;
        if (campaign.releasedAmount < campaign.totalValue) {
            uint256 remainingAmount = campaign.totalValue - campaign.releasedAmount;
            campaign.releasedAmount = campaign.totalValue;
            paymentVault.releasePayment(campaignId, campaign.creator, remainingAmount);
        }
        emit CampaignCompleted(uint256(bytes32(campaignId)));
    }
    
    function cancelCampaign(bytes4 campaignId) external onlyBrand(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.status == CampaignStatus.Created || campaign.status == CampaignStatus.Active, 
                "CampaignManager: campaign cannot be cancelled");
        campaign.status = CampaignStatus.Cancelled;
        emit CampaignCancelled(uint256(bytes32(campaignId)));
    }
    
    function expireCampaign(bytes4 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.status == CampaignStatus.Active, "CampaignManager: campaign is not active");
        require(block.timestamp > campaign.deadline, "CampaignManager: campaign deadline has not passed");
        campaign.status = CampaignStatus.Expired;
        checkMilestones(campaignId);
        emit CampaignExpired(uint256(bytes32(campaignId)));
    }
    
    function getCampaignDetails(bytes4 campaignId) external view returns (Campaign memory) {
        return campaigns[campaignId];
    }
}