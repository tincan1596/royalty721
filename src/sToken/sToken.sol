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
    error DontActSmart();

    event Minted(uint256 indexed id, address indexed to);
    event TransferBlocked(uint256 indexed id, address indexed from, address indexed to);
    event ApprovalRestricted(uint256 indexed id, address indexed operator);
    event HallSet(address indexed hall);

    address public theHall;
    address public immutable owner;
    string internal constant baseURI = "ipfs://base/";
    bool public hallSet;
    string internal constant _JSON_SUFFIX = ".json";

    constructor() ERC721("sToken", "sTK") {
        theHall = address(0);
        owner = msg.sender;
        _setDefaultRoyalty(owner, 500);
        unchecked {
            for (uint256 i; i < 10; ++i) {
                _mint(owner, i);
                emit Minted(i, owner);
            }
        }
    }

    // only for testing purposes
    function mint (address to, uint256 id) external {
        if (msg.sender != owner) revert DontActSmart();
        _mint(to, id);
        emit Minted(id, to);
    }

    function _checkHallSet() internal view {
        if (!hallSet) revert HallNotFixed();
    }

    function setTheHall(address _theHall) external {
        if (msg.sender != owner) revert DontActSmart();
        if (_theHall == address(0)) revert HallNotFixed();
        if (hallSet) revert HallFixed();
        hallSet = true;
        theHall = _theHall;
        emit HallSet(_theHall);
    }

    function tokenURI(uint256 id) public pure override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id), _JSON_SUFFIX));
    }

    function approve(address operator, uint256 id) public override {
        _checkHallSet();
        if (operator != theHall) {
            emit ApprovalRestricted(id, operator);
            revert OnlyMarketplace();
        }
        super.approve(operator, id);
    }

    function setApprovalForAll(address operator, bool approved) public override {
        _checkHallSet();
        if (operator != theHall) {
            emit ApprovalRestricted(type(uint256).max, operator);
            revert OnlyMarketplace();
        }
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 id) public override {
        _checkHallSet();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.transferFrom(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id) public override {
        _checkHallSet();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public override {
        _checkHallSet();
        if (msg.sender != theHall) {
            revert TransferRestricted(id, from, to);
        }
        super.safeTransferFrom(from, to, id, data);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f // ERC721Metadata
            || interfaceId == 0x2a55205a // ERC2981
            || super.supportsInterface(interfaceId);
    }
}
