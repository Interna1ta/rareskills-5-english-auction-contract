// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {NFTAuction} from "../src/NFTAuction.sol";

contract NFTAuctionTest is Test {
    NFTAuction auction;
    address constant NFT_ADDRESS = address(0x123);
    uint256 constant RESERVE_PRICE = 100;
    uint256 constant BID_AMOUNT = 150;
    // uint256 constant DEADLINE = block.timestamp + 3_600;

    function beforeEach() public {
        auction = new NFTAuction();
    }
}
