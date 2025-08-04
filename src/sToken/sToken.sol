// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract sToken is ERC721, ERC2981 {
    error OnlyMarketplace();
    error TransferRestricted(uint256 id, address from, address to);
    error InvalidHallAddress();

    event Minted(uint256 indexed id, address indexed to);
    event TransferBlocked(uint256 indexed id, address indexed from, address indexed to);
    event ApprovalRestricted(uint256 indexed id, address indexed operator);

    address public immutable theHall;
    string public baseURI;

    constructor(address _theHall, string memory _baseURI) ERC721("sToken", "sTK") {
        if (_theHall == address(0)) revert InvalidHallAddress();
        theHall = _theHall;
        baseURI = _baseURI;
        _setDefaultRoyalty(_theHall, 500);
        unchecked {
            for (uint256 i; i < 10; ++i) {
                _mint(msg.sender, i);
                emit Minted(i, msg.sender);
            }
        }
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id), ".json"));
    }

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

    function transferFrom(address from, address to, uint256 id) public override {
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.transferFrom(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public override {
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public override {
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id, data);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return interfaceId == type(ERC721).interfaceId || interfaceId == type(ERC2981).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
