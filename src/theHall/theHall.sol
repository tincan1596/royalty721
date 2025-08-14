// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISToken {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract TheHall is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    error ZeroPrice();
    error NotOwner();
    error AlreadyListed();
    error NotSeller();
    error NotListed();
    error NotTokenOwner();
    error InvalidWithdrawal();
    error NotApproved();
    error InvalidPrice();

    struct Listing {
        address seller;
        uint256 price;
    }

    IERC20 public immutable currency;
    ISToken public immutable sToken;

    mapping(uint256 => Listing) public listings;

    event ListingCreated(uint256 indexed id, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed id, address indexed seller);
    event TokenPurchased(
        uint256 indexed id, address indexed seller, address indexed buyer, uint256 price, uint256 royalty
    );
    event TokensWithdrawn(address indexed token, uint256 amount, address indexed to, address indexed by);

    constructor(IERC20 _currency, ISToken _sToken) {
        currency = _currency;
        sToken = _sToken;

        bool isERC721 = IERC165(address(_sToken)).supportsInterface(type(IERC721).interfaceId);
        require(isERC721, "sToken must be ERC721");

        bool isERC2981 = IERC165(address(_sToken)).supportsInterface(0x2a55205a);
        require(isERC2981, "sToken must support ERC2981");
    }

    // only for the tests
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    // delete the block written above after testing

    function createListing(uint256 id, uint256 price) external whenNotPaused {
        if (price == 0) revert ZeroPrice();
        if (sToken.ownerOf(id) != msg.sender) revert NotOwner();
        if (listings[id].seller != address(0)) revert AlreadyListed();
        if (sToken.getApproved(id) != address(this) && !sToken.isApprovedForAll(msg.sender, address(this))) {
            revert NotApproved();
        }

        listings[id] = Listing(msg.sender, price);
        emit ListingCreated(id, msg.sender, price);
    }

    function cancelListing(uint256 id) external whenNotPaused {
        Listing memory lst = listings[id];
        if (lst.seller != msg.sender) revert NotSeller();

        delete listings[id];
        emit ListingCancelled(id, msg.sender);
    }

    function buyToken(uint256 id, uint256 expectedPrice) external nonReentrant whenNotPaused {
        Listing memory lst = listings[id];
        if (lst.seller == address(0)) revert NotListed();
        if (sToken.ownerOf(id) != lst.seller) revert NotTokenOwner();
        if (lst.price != expectedPrice) revert InvalidPrice();

        delete listings[id];
        (address recv, uint256 royalty) = sToken.royaltyInfo(id, lst.price);
        
        if (royalty > 0) currency.safeTransfer(recv, royalty);
        currency.safeTransferFrom(msg.sender, lst.seller, lst.price - royalty);
        sToken.safeTransferFrom(lst.seller, msg.sender, id);

        emit TokenPurchased(id, lst.seller, msg.sender, lst.price, royalty);
    }

    function withdrawStuckTokens(address tokenAddr, uint256 amount, address to) external onlyOwner {
        if (to == address(0) || amount == 0) revert InvalidWithdrawal();

        uint256 bal = IERC20(tokenAddr).balanceOf(address(this));
        if (amount > bal) revert InvalidWithdrawal();

        IERC20(tokenAddr).safeTransfer(to, amount);
        emit TokensWithdrawn(tokenAddr, amount, to, msg.sender);
    }
}
