//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

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
        uint256 currentBid;
        uint256 highestBid;
        address bidderaddr;
        bool listed;
        bool sold;
    }

    constructor(address usdtAdd) {
        usdtToken = IERC20(usdtAdd);
    }

    mapping(uint256 => NFTdetail) public NFTdetails;

    function listNFT(address _NFTcontractAddr , uint256 _tokenId, uint256 _minAskUSDT) external {
          NFTcontract = IERC721(_NFTcontractAddr);
        require(
            NFTcontract.ownerOf(_tokenId) == msg.sender,
            "Caller is not an owner"
        );
        NFTdetails[listId] = NFTdetail({
            NFTowner: msg.sender,
           NFTContractAddr : _NFTcontractAddr,
            TokenId :_tokenId,
            minAskUSDT: _minAskUSDT,
            timeStartAt: block.timestamp,
            timeEndAt: block.timestamp + 2 minutes,
            currentBid: 0,
            highestBid: 0,
            bidderaddr: address(0),
            listed: true,
            sold: false
        });


        require(
            NFTcontract.isApprovedForAll(msg.sender , address(this)),
            "Allowance required"
        );
        NFTcontract.transferFrom(msg.sender, address(this), _tokenId);
        listId++;

    }

    function toGetHighestBid(uint256 _listId) public view returns (uint256) {
        NFTdetail memory nftdetail = NFTdetails[_listId];
        return nftdetail.highestBid;
    }

    function tocheckListing(uint256 _listId) public view returns (bool) {
        NFTdetail memory nftdetail = NFTdetails[_listId];
        return nftdetail.listed;
    }

    function checkRemainingTime(uint256 _listId)
        public
        view
        returns (uint256)
    {
        NFTdetail memory nftdetail = NFTdetails[_listId];
        require(nftdetail.listed == true, "This NFT haven't listed yet");
        require(block.timestamp <= nftdetail.timeEndAt, "Bidding over");
        return (nftdetail.timeEndAt - block.timestamp);
    }

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

        nftdetail.currentBid = _bidAmount;
        if (_bidAmount > nftdetail.currentBid) {
            nftdetail.highestBid = _bidAmount;
            nftdetail.bidderaddr = msg.sender;
        } else {
            nftdetail.highestBid = nftdetail.currentBid;
            nftdetail.bidderaddr = msg.sender;
        }
    }

    function execute(uint256 _listId) external {
        NFTdetail storage nftdetail = NFTdetails[_listId];
        require(
            nftdetail.NFTowner == msg.sender ||
                nftdetail.bidderaddr == msg.sender,
            "Caller is neither an owner nor buyer of NFT"
        );
        require(block.timestamp >= nftdetail.timeEndAt, "bid is not over yet");
        uint256 brokerage = (nftdetail.highestBid * 10) / 1000;
        usdtToken.transferFrom(nftdetail.bidderaddr, address(this), brokerage);
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
        nftdetail.listed = false;
    }
}
