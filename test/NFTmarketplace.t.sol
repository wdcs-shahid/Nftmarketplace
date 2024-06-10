// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketPlace} from "../src/NFTmarketplace.sol";
import {MyToken} from "../src/USDT.sol";
import {Nft1} from "../src/NFT1.sol";
import {Nft2} from "../src/NFT2.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract NFTMarketPlaceTest is Test {
    NFTMarketPlace public nftmarketplace;
    MyToken public usdt;
    Nft1 public nft1;
    Nft2 public nft2;

    address public nftOwner1 = address(111111);
    address public nftOwner2 = address(222222);
    address public nftOwner3 = address(888888);
    address public bidder1 = address(333333);
    address public bidder2 = address(444444);
    address public bidder3 = address(555555);

    function setUp() public {
        usdt = new MyToken();
        nft1 = new Nft1();
        nft2 = new Nft2();
        nftmarketplace = new NFTMarketPlace(address(usdt));

        usdt.mint(bidder1, 1000000);
        usdt.mint(bidder2, 1000000);
        usdt.mint(bidder3, 1000000);

        nft1.safeMint(nftOwner1);
        nft2.safeMint(nftOwner2);
        nft1.safeMint(nftOwner3);
    }

    function stroingListNft(
        address _owner,
        IERC721 _contract,
        uint _tokenId,
        uint _amount
    ) public {
        vm.startPrank(_owner);
        assertEq(
            _contract.ownerOf(_tokenId),
            _owner,
            "You are not an owner of NFT"
        );
        _contract.setApprovalForAll(address(nftmarketplace), true);
        nftmarketplace.listNFT(address(_contract), _tokenId, _amount);
        vm.stopPrank();
    }

    function storeBidder(address _bidder, uint _amount, uint _listId) internal {
        vm.startPrank(_bidder);
        assertGe(usdt.balanceOf(_bidder), _amount);
        usdt.approve(address(nftmarketplace), _amount);
        nftmarketplace.bid(_listId, _amount);
        vm.stopPrank();
    }

    function testListNft() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        stroingListNft(nftOwner2, nft2, 0, 15000);
        stroingListNft(nftOwner3, nft1, 1, 20000);
    }

    function testBid() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        stroingListNft(nftOwner2, nft2, 0, 15000);
        storeBidder(bidder2, 25000, 1);
    }
    function testFail_Bid() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 20000, 0);
        storeBidder(bidder2, 15000, 0);
    }

    function test_execute() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        storeBidder(bidder2, 20000, 0);
        uint previousBalance = usdt.balanceOf(bidder2);

        vm.startPrank(nftOwner1);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(0);
        assertEq(usdt.balanceOf(bidder2), previousBalance - 20000);
        vm.stopPrank();
    }

    function testFail_exexuteWith_differentOwner() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        storeBidder(bidder2, 20000, 0);

        vm.startPrank(nftOwner2);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(0);
        vm.stopPrank();
    }

    function test_executeWith_highestBidder() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        storeBidder(bidder2, 20000, 0);
        uint previousBalance = usdt.balanceOf(bidder2);

        vm.startPrank(bidder2);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(0);
        assertEq(usdt.balanceOf(bidder2), previousBalance - 20000);
        vm.stopPrank();
    }

    function testFail_execute_For_BidTime() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        storeBidder(bidder2, 20000, 0);

        vm.startPrank(nftOwner1);
        vm.warp(block.timestamp + 1 minutes);
        nftmarketplace.execute(0);
        vm.stopPrank();
    }

    function test_brokerage() public {
        test_execute();
        uint brokerage = (20000 * 10) / 1000;
        assertEq(usdt.balanceOf(nftOwner1), 20000 - brokerage);
    }

    function test_execute_ForMoreNFTs() public {
        stroingListNft(nftOwner1, nft1, 0, 10000);
        storeBidder(bidder1, 15000, 0);
        storeBidder(bidder2, 20000, 0);
        uint previousBalanceOfBidder2 = usdt.balanceOf(bidder2);

        vm.startPrank(nftOwner1);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(0);
        uint brokerage1 = (20000 * 10) / 1000;
        assertEq(usdt.balanceOf(bidder2), previousBalanceOfBidder2 - 20000);
        vm.stopPrank();

        stroingListNft(nftOwner2, nft2, 0, 15000);
        storeBidder(bidder3, 25000, 1);
        uint previousBalanceOfBidder3 = usdt.balanceOf(bidder3);

        vm.startPrank(nftOwner2);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(1);
        uint brokerage2 = (25000 * 10) / 1000;
        assertEq(usdt.balanceOf(bidder3), previousBalanceOfBidder3 - 25000);
        vm.stopPrank();

        uint brokerage = brokerage1 + brokerage2;
        assertEq(usdt.balanceOf(address(nftmarketplace)), brokerage);
    }

    function test_execute_forNoBid() public{
        stroingListNft(nftOwner1, nft1, 0, 10000);


        vm.startPrank(nftOwner1);
        vm.warp(block.timestamp + 1 days);
        nftmarketplace.execute(0); 
        assertEq(nft1.ownerOf(0), nftOwner1);    
        vm.stopPrank();
        
    }
}
