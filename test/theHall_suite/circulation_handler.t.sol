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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}

interface IHall {
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

    address[] public actors;

    mapping(uint256 => bool) public minted;
    mapping(uint256 => address) public lastSeller;
    mapping(uint256 => uint256) public listedPrice;

    uint256 public sumPrice;
    uint256 public sumRoyalty;
    uint256 public sumRevenue;

    constructor(address _usdc, address _stoken, address _hall, address _stokenOwner, address[] memory _actors) {
        usdc = IMUSDC(_usdc);
        stoken = IStoken(_stoken);
        hall = IHall(_hall);
        stokenOwner = _stokenOwner;
        for (uint256 i; i < _actors.length; i++) {
            actors.push(_actors[i]);
        }
    }

    function actorsLen() public view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _distinct(uint256 seed, address avoid) internal view returns (address) {
        if (actors.length < 2 || avoid == address(0)) return _actor(seed);
        address a = _actor(seed);
        return a == avoid ? _actor(seed + 1) : a;
    }

    function mintAndList(uint256 sellerSeed, uint256 id, uint256 rawPrice, uint256 approveModeSeed) public {
        uint256 tokenId = id % 10;
        address seller = _actor(sellerSeed);
        uint256 price = _price(rawPrice);

        if (!minted[tokenId]) {
            vm.startPrank(stokenOwner);
            stoken.mint(seller, tokenId);
            vm.stopPrank();
            minted[tokenId] = true;
        }

        if (!stoken.isApprovedForAll(seller, address(hall)) && stoken.getApproved(tokenId) != address(hall)) {
            vm.startPrank(seller);
            if (approveModeSeed % 2 == 0) {
                stoken.setApprovalForAll(address(hall), true);
            } else {
                stoken.approve(address(hall), tokenId);
            }
            vm.stopPrank();
        }

        if (stoken.ownerOf(tokenId) == seller) {
            vm.startPrank(seller);
            try hall.createListing(tokenId, price) {
                lastSeller[tokenId] = seller;
                listedPrice[tokenId] = price;
            } catch {}
            vm.stopPrank();
        }
    }

    function cancel(uint256 callerSeed, uint256 id) public {
        uint256 tokenId = id % 10;
        address caller = _actor(callerSeed);
        vm.startPrank(caller);
        try hall.cancelListing(tokenId) {
            listedPrice[tokenId] = 0;
        } catch {}
        vm.stopPrank();
    }

    function buy(uint256 buyerSeed, uint256 id) public {
        uint256 tokenId = id % 10;
        uint256 price = listedPrice[tokenId];
        if (price == 0) return;

        address seller = lastSeller[tokenId];
        address buyer = _distinct(buyerSeed, seller);

        usdc.mint(buyer, price);
        vm.startPrank(buyer);
        usdc.approve(address(hall), price);
        vm.stopPrank();

        (, uint256 royalty) = stoken.royaltyInfo(tokenId, price);
        uint256 revenue = price - royalty;

        vm.startPrank(buyer);
        try hall.buyToken(tokenId, price) {
            sumPrice += price;
            sumRoyalty += royalty;
            sumRevenue += revenue;
            listedPrice[tokenId] = 0;
        } catch {}
        vm.stopPrank();
    }

    function mintListBuy(uint256 sellerSeed, uint256 buyerSeed, uint256 id, uint256 rawPrice, uint256 approveModeSeed)
        external
    {
        mintAndList(sellerSeed, id, rawPrice, approveModeSeed);
        buy(buyerSeed, id);
    }

    function _price(uint256 x) internal pure returns (uint256) {
        uint256 minP = 1e6;
        uint256 maxP = 1_000_000e6;
        uint256 r = x % (maxP - minP + 1);
        return r + minP;
    }
}
