// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

interface IMUSDC {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IStoken {
    function mint(address to, uint256 id) external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
    function ownerOf(uint256 tokenId) external view returns (address);
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}

interface IHall {
    struct Listing {
        address seller;
        uint256 price;
    }

    function listings(uint256 id) external view returns (Listing memory);

    function createListing(uint256 id, uint256 price) external;
    function cancelListing(uint256 id) external;
    function buyToken(uint256 id, uint256 expectedPrice) external;
}

contract HallHandler {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IMUSDC public immutable usdc;
    IStoken public immutable stoken;
    IHall public immutable hall;
    address public immutable stokenOwner;

    uint256 public sumPrice;
    uint256 public sumRoyalty;
    uint256 public sumRevenue;

    constructor(address _usdc, address _stoken, address _hall, address _stokenOwner) {
        usdc = IMUSDC(_usdc);
        stoken = IStoken(_stoken);
        hall = IHall(_hall);
        stokenOwner = _stokenOwner;
    }

    function mintAndList(uint256 seed, uint256 rawId, uint256 rawPrice, uint256 approveModeSeed) public {
        address seller = _addr(seed);
        uint256 tokenId = rawId % 10;
        uint256 price = _price(rawPrice);

        // Mint if not owned by anyone
        _ensureMinted(seller, tokenId);

        // Approve hall if needed
        if (!stoken.isApprovedForAll(seller, address(hall)) && stoken.getApproved(tokenId) != address(hall)) {
            vm.startPrank(seller);
            if (approveModeSeed % 2 == 0) {
                stoken.setApprovalForAll(address(hall), true);
            } else {
                stoken.approve(address(hall), tokenId);
            }
            vm.stopPrank();
        }

        // List
        if (stoken.ownerOf(tokenId) == seller) {
            vm.startPrank(seller);
            try hall.createListing(tokenId, price) {} catch {}
            vm.stopPrank();
        }
    }

    function buy(uint256 seed, uint256 rawId) public {
        address buyer = _addr(seed);
        uint256 tokenId = rawId % 10;

        IHall.Listing memory lst = hall.listings(tokenId);
        if (lst.price == 0 || lst.seller == address(0) || lst.seller == buyer) return;

        uint256 price = lst.price;

        // fund buyer
        usdc.mint(buyer, price);
        vm.startPrank(buyer);
        usdc.approve(address(hall), price);
        vm.stopPrank();

        // compute royalty
        (, uint256 royalty) = stoken.royaltyInfo(tokenId, price);
        uint256 revenue = price - royalty;

        // buy
        vm.startPrank(buyer);
        try hall.buyToken(tokenId, price) {
            sumPrice += price;
            sumRoyalty += royalty;
            sumRevenue += revenue;
        } catch {}
        vm.stopPrank();
    }

    function mintListBuy(uint256 sSeed, uint256 bSeed, uint256 rawId, uint256 rawPrice, uint256 approveSeed) external {
        mintAndList(sSeed, rawId, rawPrice, approveSeed);
        buy(bSeed, rawId);
    }

    // === Internals ===

    function _ensureMinted(address to, uint256 tokenId) internal {
        // If nobody owns the tokenId yet, mint it
        try stoken.ownerOf(tokenId) returns (address owner) {
            if (owner != address(0)) return;
        } catch {
            vm.startPrank(stokenOwner);
            stoken.mint(to, tokenId);
            vm.stopPrank();
        }
    }

    function _addr(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(seed)))));
    }

    function _price(uint256 x) internal pure returns (uint256) {
        uint256 minP = 10e6;
        uint256 maxP = 1_000e6;
        return (x % (maxP - minP + 1e6)) + minP;
    }
}
