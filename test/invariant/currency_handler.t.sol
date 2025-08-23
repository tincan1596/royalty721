// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

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

contract HallHandler is Test {
    IMUSDC public immutable usdc;
    IStoken public immutable stoken;
    IHall public immutable hall;
    address public immutable stokenOwner;

    uint256 public sumDust;
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
        address prospect = _addr(seed);
        uint256 tokenId = rawId % 100_000;
        uint256 price = _price(rawPrice);

        address seller = _ensureMinted(prospect, tokenId);

        // check if not listed
        if (hall.listings(tokenId).seller == address(0)) {
            vm.startPrank(seller);

            // approval if not listed
            if (stoken.getApproved(tokenId) != address(hall) && !stoken.isApprovedForAll(seller, address(hall))) {
                if (approveModeSeed % 2 == 0) {
                    stoken.approve(address(hall), tokenId);
                } else {
                    stoken.setApprovalForAll(address(hall), true);
                }
            }

            hall.createListing(tokenId, price);
            vm.stopPrank();
        } else {
            // approval if listed
            if (stoken.getApproved(tokenId) != address(hall) && !stoken.isApprovedForAll(seller, address(hall))) {
                if (approveModeSeed % 2 == 0) {
                    stoken.approve(address(hall), tokenId);
                } else {
                    stoken.setApprovalForAll(address(hall), true);
                }
            }
        }
    }

    function buy(uint256 seed, uint256 rawId) internal {
        address buyer = _addr(seed);
        uint256 tokenId = rawId % 100_000;

        IHall.Listing memory lst = hall.listings(tokenId);

        vm.assume(lst.price != 0);
        vm.assume(lst.seller != address(0));
        vm.assume(lst.seller != buyer);
        vm.assume(buyer != address(0));

        uint256 price = lst.price;

        // fund buyer
        vm.prank(stokenOwner);
        usdc.mint(buyer, price);
        vm.startPrank(buyer);
        usdc.approve(address(hall), price);
        vm.stopPrank();

        // compute royalty
        (, uint256 royalty) = stoken.royaltyInfo(tokenId, price);
        uint256 revenue = price - royalty;
        uint256 r5 = price * 5;
        uint256 dust = r5 % 100;

        // buy
        vm.startPrank(buyer);
        try hall.buyToken(tokenId, price) {
            sumDust += dust;
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

    function _ensureMinted(address to, uint256 tokenId) internal returns (address seller) {
        address currentOwner;
        try stoken.ownerOf(tokenId) returns (address o) {
            currentOwner = o;
        } catch {
            currentOwner = address(0);
        }

        if (currentOwner == address(0)) {
            vm.startPrank(stokenOwner);
            stoken.mint(to, tokenId);
            vm.stopPrank();
            return to;
        } else {
            return currentOwner;
        }
    }

    function _addr(uint256 seed) internal pure returns (address) {
        uint256 Addr = bound(seed, 1, 20);
        address addr = address(uint160(uint256(keccak256(abi.encode(Addr)))));

        return addr;
    }

    function _price(uint256 x) internal pure returns (uint256) {
        return bound(x, 10e6, 1000e6);
    }
}
