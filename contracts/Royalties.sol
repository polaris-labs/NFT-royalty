// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address account, uint256 amount) external;
}

interface ERC721 {
    function ownerOf(uint256 tokenId) external returns (address);
}


/// @title Royalties for Non-Fungible Tokens
/// @dev Contract for the split between community royalties and dev royalties
///
contract Royalties is Ownable {
    uint256 public communityClaimedERC20 = 0;
    uint256 public creatorClaimedERC20 = 0;
    uint256 public communityClaimed = 0;
    uint256 public creatorClaimed = 0;

    uint256 public creatorRoyalties = 1; // percentage from total NFT price
    uint256 public communityRoyalties = 3; // percentage from total NFT price

    uint256 public collectionSize = 10000;

    address public tokenFeesAddress; // WAVAX / WBNB / WETH / WMATIC
    address public creatorAddress; // the creator address
    address public collectionAddress; // the collection address

    mapping(uint256 => uint256) private communityClaims;
    mapping(address => uint256) private addressClaims;

    mapping(uint256 => uint256) private communityClaimsERC20;
    mapping(address => uint256) private addressClaimsERC20;

    event CommunityClaimed(address owner, uint256 amount, uint256 tokenID);
    event CreatorClaimed(uint256 amount);
    event CommunityERC20Claimed(address owner, uint256 amount, uint256 tokenID);
    event CreatorERC20Claimed(uint256 amount);
    event RoyaltiesCreated(address collectionAddress);

    constructor(
        address _tokenFeesAddress,
        address _creatorAddress,
        address _collectionAddress,
        uint256 _collectionSize
    ) {
        tokenFeesAddress = _tokenFeesAddress;
        creatorAddress = _creatorAddress;
        collectionAddress = _collectionAddress;
        collectionSize = _collectionSize;
        emit RoyaltiesCreated(collectionAddress);
    }

    receive() external payable {}

    /// @dev set royalties address (weth)
    function setTokenFeesAddress(address _tokenFeesAddress) external onlyOwner {
        tokenFeesAddress = _tokenFeesAddress;
    }

    /// @dev set creator address, can be another contract
    function setCreatorAddress(address _creatorAddress) external onlyOwner {
        creatorAddress = _creatorAddress;
    }

    /// @dev set only smaller collection size, can't increase size
    function setCollectionSize(uint256 _collectionSize) external onlyOwner {
        require(_collectionSize < collectionSize, 'Cannot increase collection size');
        collectionSize = _collectionSize;
    }

    /// @dev set creator royalties
    function setCreatorRoyalties(uint256 _creatorRoyalties) external onlyOwner {
        creatorRoyalties = _creatorRoyalties;
    }

    /// @dev set creator royalties
    function setCommunityRoyalties(uint256 _communityRoyalties) external onlyOwner {
        communityRoyalties = _communityRoyalties;
    }

    /// @dev get total royalties
    /// @return total royalties
    function getTotalRoyalties() public view returns (uint256) {
        return creatorRoyalties + communityRoyalties;
    }

    /// @dev get royalties split
    /// @return creator roylaties
    /// @return community royalties
    function getRoyalties() public view returns (uint256, uint256) {
        return (creatorRoyalties, communityRoyalties);
    }

    /// @dev get total collected
    /// @return total collected
    function getTotalCollectedERC20() public view returns (uint256) {
        uint256 balance = ERC20(tokenFeesAddress).balanceOf(address(this));
        return balance + creatorClaimedERC20 + communityClaimedERC20;
    }
    
    /// @dev get total collected native token balance
    /// @return total collected
    function getTotalCollected() public view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance + creatorClaimed + communityClaimed;
    }

    /// @dev get creator balance
    /// @return creator total balance
    function getCreatorBalanceERC20() public view returns (uint256) {
        uint256 _creatorRoyalties = (creatorRoyalties * 100) / getTotalRoyalties();
        return (getTotalCollectedERC20() * _creatorRoyalties) / 100 - creatorClaimedERC20;
    }

    /// @dev get creator balance native token balance
    /// @return creator total balance
    function getCreatorBalance() public view returns (uint256) {
        uint256 _creatorRoyalties = (creatorRoyalties * 100) / getTotalRoyalties();
        return (getTotalCollected() * _creatorRoyalties) / 100 - creatorClaimed;
    }

    /// @dev get single token total royalties
    /// @return single token royalties
    function getTokenTotalRoyaltiesERC20() public view returns (uint256) {
        uint256 _communityRoyalties = (communityRoyalties * 100) / getTotalRoyalties();
        return ((getTotalCollectedERC20() * _communityRoyalties) / 100) / collectionSize;
    }

    /// @dev get single token total royalties native token
    /// @return single token royalties
    function getTokenTotalRoyalties() public view returns (uint256) {
        uint256 _communityRoyalties = (communityRoyalties * 100) / getTotalRoyalties();
        return ((getTotalCollected() * _communityRoyalties) / 100) / collectionSize;
    }

    /// @dev get single token balance
    /// @return single token balance
    function getTokenBalanceERC20(uint256 tokenID) public view returns (uint256) {
        return getTokenTotalRoyaltiesERC20() - communityClaimsERC20[tokenID];
    }

    /// @dev get single native token balance
    /// @return single token balance
    function getTokenBalance(uint256 tokenID) public view returns (uint256) {
        return getTokenTotalRoyalties() - communityClaims[tokenID];
    }

    /// @dev get token balances for each token from an array of tokenIDs
    function getTokensBalanceERC20(uint256[] memory tokenIDs) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i<tokenIDs.length; i++) {
            uint256 balance = getTokenBalanceERC20(tokenIDs[i]);
            totalBalance = (totalBalance + balance);
        }
        return totalBalance;
    }

    /// @dev get native token balances for each token from an array of tokenIDs
    function getTokensBalance(uint256[] memory tokenIDs) public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i<tokenIDs.length; i++) {
            uint256 balance = getTokenBalance(tokenIDs[i]);
            totalBalance = (totalBalance + balance);
        }
        return totalBalance;
    }

    /// @dev get address total claims
    /// @return address total claims
    function getAddressClaimsERC20(address account) public view returns (uint256) {
        return addressClaimsERC20[account];
    }
    
    /// @dev get address total claims for native token
    /// @return address total claims
    function getAddressClaims(address account) public view returns (uint256) {
        return addressClaims[account];
    }

    /// @dev claim community royalties per token id
    function claimCommunity(uint256 tokenID) public {
        uint256 balanceERC20 = getTokenBalanceERC20(tokenID);
        uint256 balance = getTokenBalance(tokenID);
        
        address owner = ERC721(collectionAddress).ownerOf(tokenID);
        require(owner != address(0), "Owner can not be dead address");
        if (balance > 0) {
            payable(owner).transfer(balance);
            communityClaims[tokenID] = communityClaims[tokenID] + balance;
            addressClaims[owner] = addressClaims[owner] + balance;
            communityClaimed = communityClaimed + balance;
            emit CommunityClaimed(owner, balance, tokenID);
        }
        if (balanceERC20 > 0) {
            ERC20(tokenFeesAddress).transfer(owner, balanceERC20);
            communityClaimsERC20[tokenID] = communityClaimsERC20[tokenID] + balanceERC20;
            addressClaimsERC20[owner] = addressClaimsERC20[owner] + balanceERC20;
            communityClaimedERC20 = communityClaimedERC20 + balanceERC20;
            emit CommunityERC20Claimed(owner, balance, tokenID);
        }

    }

    /// @dev claim community from an array of tokenIDs
    function claimCommunityBatch(uint256[] calldata tokenIDs) external {
        for (uint256 i=0; i<tokenIDs.length; i++) {
            claimCommunity(tokenIDs[i]);
        }
    }

    /// @dev claim creator royalties
    function claimCreator() external {
        require(msg.sender == creatorAddress, "Only creator can claim");
        uint256 balanceERC20 = getCreatorBalanceERC20();
        uint256 balance = getCreatorBalance();
        require(balanceERC20 > 0 || balance > 0, "No balance to claim");
        if (balance > 0) {
            payable(creatorAddress).transfer(balance);
            creatorClaimed = creatorClaimed + balance;
            emit CreatorClaimed(balance);
        }
        if (balanceERC20 > 0) {
            ERC20(tokenFeesAddress).transfer(creatorAddress, balanceERC20);
            creatorClaimedERC20 = creatorClaimedERC20 + balanceERC20;
            emit CreatorERC20Claimed(balanceERC20);
        }
    }
}