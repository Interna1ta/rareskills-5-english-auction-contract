// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error NFTAuction__OnlySeller(string message);
error NFTAuction__AuctionNotExist(string message);
error NFTAuction__AuctionEnded(string message);
error NFTAuction__DeadlineInTheFuture(string message);
error NFTAuction__ReserveGreaterThanZero(string message);
error NFTAuction__AuctionAlreadyExists(string message);
error NFTAuction__SenderNotOwnToken(string message);
error NFTAuction__BidGreaterThanZero(string message);
error NFTAuction__BidHigherThanCurrentHighestBid(string message);
error NFTAuction__NoBidToWithdraw(string message);
error NFTAuction__AuctionNotEnded(string message);
error NFTAuction__ReservePriceNotMet(string message);

contract NFTAuction {
    struct Auction {
        uint256 nftId;
        address seller;
        address payable highestBidder;
        uint256 highestBid;
        uint256 reservePrice;
        uint256 deadline;
        bool ended;
    }

    mapping(address => Auction) public s_auctions;
    mapping(address => mapping(address => uint256)) public s_bids;

    modifier onlySeller(address _auctionAddress) {
        if (msg.sender != s_auctions[_auctionAddress].seller) {
            revert NFTAuction__OnlySeller(
                "Only the seller can call this function"
            );
        }
        _;
    }

    modifier auctionExists(address _auctionAddress) {
        if (s_auctions[_auctionAddress].deadline == 0) {
            revert NFTAuction__AuctionNotExist("Auction does not exist");
        }
        _;
    }

    modifier notEnded(address _auctionAddress) {
        if (s_auctions[_auctionAddress].ended) {
            revert NFTAuction__AuctionEnded("Auction has already ended");
        }
        _;
    }

    event NewAuction(
        address indexed _seller,
        address indexed _auctionAddress,
        uint256 indexed _nftId,
        uint256 _reservePrice,
        uint256 _deadline
    );
    event NewBid(
        address indexed _auctionAddress,
        address indexed _bidder,
        uint256 indexed _nftId,
        uint256 _amount
    );
    event AuctionEnded(
        address indexed _auctionAddress,
        address indexed _winner,
        uint256 indexed _nftId,
        uint256 _amount
    );
    event BidWithdrawn(
        address indexed _auctionAddress,
        address indexed _bidder,
        uint256 indexed _nftId,
        uint256 _amount
    );

    function deposit(
        address _auctionAddress,
        uint256 _nftId,
        uint256 _reservePrice,
        uint256 _deadline
    ) external {
        if (_deadline <= block.timestamp) {
            revert NFTAuction__DeadlineInTheFuture(
                "Deadline must be in the future"
            );
        }
        if (_reservePrice == 0) {
            revert NFTAuction__ReserveGreaterThanZero(
                "Reserve price must be greater than zero"
            );
        }
        if (s_auctions[_auctionAddress].deadline != 0) {
            revert NFTAuction__AuctionAlreadyExists(
                "Auction already exists for this NFT"
            );
        }

        IERC721 tokenContract = IERC721(_auctionAddress);
        address tokenOwner = tokenContract.ownerOf(_nftId);
        if (tokenOwner != msg.sender) {
            revert NFTAuction__SenderNotOwnToken(
                "Sender does not own the token"
            );
        }

        IERC721(_auctionAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _nftId
        );
        s_auctions[_auctionAddress] = Auction(
            _nftId,
            msg.sender,
            payable(address(0)),
            0,
            _reservePrice,
            _deadline,
            false
        );

        emit NewAuction(
            msg.sender,
            _auctionAddress,
            _nftId,
            _reservePrice,
            _deadline
        );
    }

    function bid(
        address _auctionAddress,
        uint256 _nftId
    )
        external
        payable
        auctionExists(_auctionAddress)
        notEnded(_auctionAddress)
    {
        if (msg.value == 0) {
            revert NFTAuction__BidGreaterThanZero(
                "Bid amount must be greater than zero"
            );
        }
        if (msg.value <= s_bids[_auctionAddress][msg.sender]) {
            revert NFTAuction__BidHigherThanCurrentHighestBid(
                "Bid must be higher than current highest bid"
            );
        }

        uint256 refundAmount = s_bids[_auctionAddress][msg.sender];
        s_bids[_auctionAddress][msg.sender] = msg.value;

        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }

        s_auctions[_auctionAddress].highestBidder = payable(msg.sender);
        s_auctions[_auctionAddress].highestBid = msg.value;

        emit NewBid(_auctionAddress, msg.sender, _nftId, msg.value);
    }

    function withdrawBid(
        address _auctionAddress,
        uint256 _nftId
    ) external auctionExists(_auctionAddress) notEnded(_auctionAddress) {
        uint256 bidAmount = s_bids[_auctionAddress][msg.sender];
        if (bidAmount == 0) {
            revert NFTAuction__NoBidToWithdraw("No bid to withdraw");
        }

        s_bids[_auctionAddress][msg.sender] = 0;
        payable(msg.sender).transfer(bidAmount);

        emit BidWithdrawn(_auctionAddress, msg.sender, _nftId, bidAmount);
    }

    function sellerEndAuction(
        address _auctionAddress,
        uint256 _nftId
    ) external onlySeller(_auctionAddress) auctionExists(_auctionAddress) {
        if (block.timestamp < s_auctions[_auctionAddress].deadline) {
            revert NFTAuction__AuctionNotEnded("Auction has not ended yet");
        }
        if (
            s_auctions[_auctionAddress].highestBid <
            s_auctions[_auctionAddress].reservePrice
        ) {
            revert NFTAuction__ReservePriceNotMet("Reserve price not met");
        }

        s_auctions[_auctionAddress].ended = true;
        IERC721(_auctionAddress).safeTransferFrom(
            address(this),
            s_auctions[_auctionAddress].highestBidder,
            _nftId
        );

        uint256 amount = s_auctions[_auctionAddress].highestBid;
        s_auctions[_auctionAddress].highestBidder.transfer(amount);

        emit AuctionEnded(
            _auctionAddress,
            s_auctions[_auctionAddress].highestBidder,
            _nftId,
            amount
        );
    }
}
