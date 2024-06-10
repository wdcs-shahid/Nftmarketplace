//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

/// @title The NFTMarketPlace
/// @author Shahidkhan
/// @notice You can use this contract for making basic NFTMarketPlace to sell and buy NFTs from bidding
contract NFTMarketPlace {
    IERC20 public usdtToken;
    IERC721 public NFTcontract;
    uint256 private listId;

    struct NFTdetail {
        address NFTowner;
        address NFTContractAddr;
        uint TokenId;
        uint256 minAskUSDT;
        uint256 timeStartAt;
        uint256 timeEndAt;
        uint256 highestBid;
        address bidderaddr;
        bool listed;
        bool sold;
    }

    constructor(address usdtAdd) {
        usdtToken = IERC20(usdtAdd);
    }

    mapping(uint256 => NFTdetail) public NFTdetails;
    mapping(address => mapping(uint256 => uint256)) public nftListings;

    /// @notice listing NFTs for sell by NFTowners
    /// @dev After Listing an NFT smart contract will become owner of that NFT
    /// @param _NFTcontractAddr the address of NFT smart contract
    /// @param  _tokenId  the tokenId of NFT which is listed on marketplace
    /// @param _minAskUSDT the minimum usdt amount asked by the owner of nft
    function listNFT(
        address _NFTcontractAddr,
        uint256 _tokenId,
        uint256 _minAskUSDT
    ) external {
        NFTcontract = IERC721(_NFTcontractAddr);
        require(
            NFTcontract.ownerOf(_tokenId) == msg.sender,
            "Caller is not an owner"
        );
        NFTdetails[listId] = NFTdetail({
            NFTowner: msg.sender,
            NFTContractAddr: _NFTcontractAddr,
            TokenId: _tokenId,
            minAskUSDT: _minAskUSDT,
            timeStartAt: block.timestamp,
            timeEndAt: block.timestamp + 2 minutes,
            highestBid: 0,
            bidderaddr: address(0),
            listed: true,
            sold: false
        });

        nftListings[_NFTcontractAddr][_tokenId] = listId;

        require(
            NFTcontract.isApprovedForAll(msg.sender, address(this)),
            "Allowance required"
        );
        NFTcontract.transferFrom(msg.sender, address(this), _tokenId);
        listId++;
    }

    /// @notice checking highestbid at current time
    /// @param _listId the listId of NFT for which bidder wants to bid on
    function toGetHighestBid(uint256 _listId) public view returns (uint256) {
        NFTdetail memory nftdetail = NFTdetails[_listId];
        return nftdetail.highestBid;
    }

    /// @notice checking whether NFT is listed or not
    /// @param _NFTcontractaddr the address of NFT smart contract
    /// @param _tokenId the tokenId of NFT which is listed on marketplace
    function tocheckListing(
        address _NFTcontractaddr,
        uint256 _tokenId
    ) public view returns (bool) {
        uint256 listingId = nftListings[_NFTcontractaddr][_tokenId];
        NFTdetail memory nftdetail = NFTdetails[listingId];
        return nftdetail.listed;
    }

    /// @notice checking remaining time for bidding
    /// @param _listId the listId of NFT for which bidder wants to bid on
    function checkRemainingTime(uint256 _listId) public view returns (uint256) {
        NFTdetail memory nftdetail = NFTdetails[_listId];
        require(nftdetail.listed == true, "This NFT haven't listed yet");
        require(block.timestamp <= nftdetail.timeEndAt, "Bidding over");
        return (nftdetail.timeEndAt - block.timestamp);
    }

    /// @notice can bid for NFTs which are listed on marketplace for sell
    /// @param _listId the listId of NFT for which bidder wants to bid on
    /// @param  _bidAmount  the amount of bid in usdt by bidder
    function bid(uint256 _listId, uint256 _bidAmount) external {
        NFTdetail storage nftdetail = NFTdetails[_listId];
        require(nftdetail.listed == true, "This NFT is not for sale right now");
        require(nftdetail.timeEndAt >= block.timestamp, "Bid time is over");
        require(
            nftdetail.highestBid < _bidAmount,
            "current bid should be more than highest bid applied till now"
        );
        require(
            _bidAmount >= nftdetail.minAskUSDT,
            "Required more than or equal to minimumAskUSDT to bid"
        );
        require(
            usdtToken.balanceOf(msg.sender) >= _bidAmount,
            "Insufficient Balance"
        );
        require(
            usdtToken.allowance(msg.sender, address(this)) >= _bidAmount,
            "Insufficient Allowance"
        );

        nftdetail.highestBid = _bidAmount;
        nftdetail.bidderaddr = msg.sender;
    }

    /// @notice after completion of bid time owner and highestbidder can transfer usdt and nft ownerships respectively
    /// @dev after completion of time both NFTowner and highestbidder can call this function
    /// @param _listId the listId of NFT for which bidder wants to bid on
    function execute(uint256 _listId) external {
        NFTdetail storage nftdetail = NFTdetails[_listId];
        require(
            nftdetail.NFTowner == msg.sender ||
                nftdetail.bidderaddr == msg.sender,
            "Caller is neither an owner nor buyer of NFT"
        );
        require(block.timestamp >= nftdetail.timeEndAt, "bid is not over yet");

        if (nftdetail.highestBid == 0) {
            IERC721 nftContract = IERC721(nftdetail.NFTContractAddr);
            nftContract.safeTransferFrom(
                address(this),
                nftdetail.NFTowner,
                nftdetail.TokenId
            );
        } else {
            uint256 brokerage = (nftdetail.highestBid * 10) / 1000;
            usdtToken.transferFrom(
                nftdetail.bidderaddr,
                address(this),
                brokerage
            );
            usdtToken.transferFrom(
                nftdetail.bidderaddr,
                nftdetail.NFTowner,
                (nftdetail.highestBid - brokerage)
            );

        IERC721 nftContract = IERC721(nftdetail.NFTContractAddr);
        nftContract.safeTransferFrom(
            address(this),
            nftdetail.bidderaddr,
            nftdetail.TokenId
        );
        nftdetail.NFTowner = nftdetail.bidderaddr;
        nftdetail.sold = true;
        }
        nftdetail.listed = false;
    }
}
