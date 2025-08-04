// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// === Imports ===
import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Metadata.sol";

// === Contract ===
contract sToken is ERC721, ERC2981 {
    // --- Errors ---
    error OnlyMarketplace();
    error TransferRestricted(uint256 id, address from, address to);

    // --- Events ---
    event Minted(uint256 indexed id, address indexed to);
    event TransferisRestricted(uint256 indexed id, address indexed from, address indexed to);
    event ApprovalRestricted(uint256 indexed id, address indexed operator);

    // --- State ---
    address public immutable theHall;
    string public baseURI;

    // --- Constructor ---
    constructor(address _theHall, string memory _baseURI)
        ERC721("sToken", "sTK")
    {
        if (_theHall == address(0)) revert();
        theHall = _theHall;
        baseURI = _baseURI;

        // Set 5% royalty to theHall (500 bps)
        _setDefaultRoyalty(_theHall, 500);

        // Mint 10 NFTs with IDs 0–9
        unchecked {
            for (uint256 i; i < 10; ++i) {
                _mint(msg.sender, i);
                emit Minted(i, msg.sender);
            }
        }
    }

    // --- Metadata URI ---
    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id), ".json"));
    }

    // --- Approvals: Restricted to theHall ---
    function approve(address operator, uint256 id) public override {
        if (operator != theHall) {
            emit ApprovalRestricted(id, operator);
            revert OnlyMarketplace();
        }
        super.approve(operator, id);
    }

    function setApprovalForAll(address operator, bool approved) public override {
        if (operator != theHall) {
            emit ApprovalRestricted(type(uint256).max, operator);
            revert OnlyMarketplace();
        }
        super.setApprovalForAll(operator, approved);
    }

    // --- Transfers: Only via theHall ---
    function transferFrom(address from, address to, uint256 id) public override {
        if (msg.sender != theHall) {
            emit TransferisRestricted(id, from, to);
            revert OnlyMarketplace();
        }
        super.transferFrom(from, to, id);
    }

    // --- Interface Support ---
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC2981)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
