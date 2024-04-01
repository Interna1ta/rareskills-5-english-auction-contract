// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {NFTAuction} from "../src/NFTAuction.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract NFTAuctionTest is Test {
    NFTAuction auction;
    MyERC721 nft;
    address constant FAKE_NFT_ADDRESS = address(0x123);
    uint256 constant RESERVE_PRICE = 100;
    uint256 constant BID_AMOUNT = 150;
    address OWNER = makeAddr("OWNER");

    function setUp() public {
        vm.startPrank(OWNER);
        auction = new NFTAuction();
        nft = new MyERC721(OWNER);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(OWNER);
        vm.expectRevert();
        auction.deposit(
            FAKE_NFT_ADDRESS,
            0,
            RESERVE_PRICE,
            block.timestamp + 3_600
        );
        nft.safeMint(OWNER, 0);
        nft.approve(address(auction), 0);
        auction.deposit(
            address(nft),
            0,
            RESERVE_PRICE,
            block.timestamp + 3_600
        );
        vm.stopPrank();
    }

    function testBid() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, 0);
        nft.approve(address(auction), 0);
        vm.deal(OWNER, 1_000);
        auction.deposit(
            address(nft),
            0,
            RESERVE_PRICE,
            block.timestamp + 3_600
        );
        vm.expectRevert();
        auction.bid(address(nft), 0);
        auction.bid{value: 10}(address(nft), 0);
        vm.expectRevert();
        auction.bid{value: 1}(address(nft), 0);
        vm.stopPrank();
    }

    function testWithDrawBid() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, 0);
        nft.approve(address(auction), 0);
        vm.deal(OWNER, 1_000);
        auction.deposit(
            address(nft),
            0,
            RESERVE_PRICE,
            block.timestamp + 3_600
        );
        auction.bid{value: BID_AMOUNT}(address(nft), 0);
        auction.withdrawBid(address(nft), 0);
        vm.stopPrank();
    }

    function testSellerEndAuction() public {
        vm.startPrank(OWNER);
        nft.safeMint(OWNER, 0);
        nft.approve(address(auction), 0);
        vm.deal(OWNER, 1_000);
        auction.deposit(
            address(nft),
            0,
            RESERVE_PRICE,
            block.timestamp + 3_600
        );
        auction.bid{value: BID_AMOUNT}(address(nft), 0);
        vm.expectRevert();
        auction.sellerEndAuction(address(nft), 0);
        vm.warp(block.timestamp + 6000);
        auction.sellerEndAuction(address(nft), 0);
        vm.stopPrank();
    }
}
