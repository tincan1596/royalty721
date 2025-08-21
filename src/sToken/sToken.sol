// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract sToken is ERC721, ERC2981 {
    error OnlyMarketplace();
    error TransferRestricted(uint256 id, address from, address to);
    error HallFixed();
    error HallNotFixed();
    error NotOwner();

    event Minted(uint256 indexed id, address indexed to);
    event Approved(uint256 indexed id, address indexed operator);
    event HallSet(address indexed hall);
    event TokenTransfered(address indexed from, address indexed to, uint256 indexed id);
    event OwnerSet(address indexed owner);

    address public theHall;
    address public immutable owner;
    string internal constant baseURI = "ipfs://base/";
    bool public hallSet;
    string internal constant _JSON_SUFFIX = ".json";

    constructor() ERC721("sToken", "sTK") {
        theHall = address(0);
        owner = msg.sender;
        _setDefaultRoyalty(owner, 500);

        emit OwnerSet(owner);
    }

    function mint(address to, uint256 id) external {
        if (msg.sender != owner) revert NotOwner();
        _mint(to, id);
        emit Minted(id, to);
    }

    function setTheHall(address _theHall) external {
        if (msg.sender != owner) revert NotOwner();
        if (_theHall == address(0)) revert HallNotFixed();
        if (hallSet) revert HallFixed();
        hallSet = true;
        theHall = _theHall;
        emit HallSet(_theHall);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        theHall; // dummy read to satisfy linter
        return string(abi.encodePacked(baseURI, Strings.toString(id), _JSON_SUFFIX));
    }

    function approve(address operator, uint256 id) public override {
        if (!hallSet) revert HallNotFixed();
        if (operator != theHall) {
            revert OnlyMarketplace();
        }
        super.approve(operator, id);
        emit Approved(id, operator);
    }

    function setApprovalForAll(address operator, bool approved) public override {
        if (!hallSet) revert HallNotFixed();
        if (operator != theHall) {
            revert OnlyMarketplace();
        }
        super.setApprovalForAll(operator, approved);
        emit Approved(0, operator);
    }

    function transferFrom(address from, address to, uint256 id) public override {
        if (!hallSet) revert HallNotFixed();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.transferFrom(from, to, id);
        emit TokenTransfered(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public override {
        if (!hallSet) revert HallNotFixed();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id);
        emit TokenTransfered(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public override {
        if (!hallSet) revert HallNotFixed();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id, data);
        emit TokenTransfered(from, to, id);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f // ERC721Metadata
            || interfaceId == 0x2a55205a // ERC2981
            || super.supportsInterface(interfaceId);
    }
}
