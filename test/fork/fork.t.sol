// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/theHall/theHall.sol";
import "../../src/sToken/sToken.sol";

contract MarketplaceForkTest is Test {
    TheHall public hall;
    sToken public stoken;
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address constant USDC_WHALE = address(0x1111111111111111111111111111111111111111);

    // Test actors
    address seller = address(0xDeaDBeefDeaDBeefDeaDBeefDeaDBeefDeaD1);
    address buyer = address(0xBEEf000000000000000000000000000000000001);
    address owner = address(0xFeE1face00000000000000000000000000000002);
    uint256 tokenId = 1;

    uint256 constant ROYALTY_BP = 500;
    uint256 constant USDC_DECIMALS = 6;

    function setUp() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "cast";
        inputs[1] = "rpc";
        inputs[2] = "anvil_reset";
        vm.ffi(inputs);

        vm.startPrank(owner);
        stoken = new sToken();
        hall = new TheHall(usdc, ISToken(address(stoken)));
        stoken.setTheHall(address(hall));
        stoken.mint(seller, tokenId);
        vm.stopPrank();

        assertEq(stoken.ownerOf(tokenId), seller);
    }

    function _fundBuyerWithUSDC(address _buyer, uint256 amount) internal {
        vm.startPrank(USDC_WHALE);
        bool ok = usdc.transfer(_buyer, amount);
        require(ok, "whale transfer failed");
        vm.stopPrank();
    }

    /* ===========================================================
       Test 1: Happy path for currency circulation (USDC)
       =========================================================== */
    function testFork_CreateListingAndBuy_USDC_happyPath() public {
        uint256 price = 10 * (10 ** USDC_DECIMALS);

        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        _fundBuyerWithUSDC(buyer, 1000 * (10 ** USDC_DECIMALS));
        uint256 sellerBefore = usdc.balanceOf(seller);
        uint256 ownerBefore = usdc.balanceOf(owner);

        vm.startPrank(buyer);
        usdc.approve(address(hall), price);
        hall.buyToken(tokenId, price);
        vm.stopPrank();

        assertEq(stoken.ownerOf(tokenId), buyer);

        (address recv, uint256 royalty) = stoken.royaltyInfo(tokenId, price);
        uint256 sellerShare = price - royalty;

        assertEq(recv, owner);
        assertEq(usdc.balanceOf(owner), ownerBefore + royalty);
        assertEq(usdc.balanceOf(seller), sellerBefore + sellerShare);
    }

    /* ===========================================================
       Test 2: expectedPrice mismatch should revert (front-run protection)
       =========================================================== */
    function testFork_ExpectedPriceMismatch_reverts() public {
        uint256 price = 15 * (10 ** USDC_DECIMALS);

        // Create initial listing
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        // Seller changes listing to simulate front-run or price change
        vm.prank(seller);
        hall.cancelListing(tokenId);
        vm.prank(seller);
        hall.createListing(tokenId, price + (1 * (10 ** USDC_DECIMALS)));

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(TheHall.InvalidAmount.selector));
        hall.buyToken(tokenId, price);
    }

    /* ===========================================================
       Test 3: insufficient allowance or balance reverts
       =========================================================== */
    function testFork_InsufficientAllowanceOrBalance_reverts() public {
        uint256 price = 20 * (10 ** USDC_DECIMALS);
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        hall.buyToken(tokenId, price);
    }

    /* ===========================================================
       Test 4: Hall must be set before listing (stoken.setTheHall one-time)
       =========================================================== */
    function testFork_HallNotSet_revertsOnCreateListing() public {
        // Deploy a fresh stoken instance that doesn't have hall set (simulating misconfiguration)
        address tempOwner = address(0xCAFECaFe00000000000000000000000000000003);
        vm.prank(tempOwner);
        sToken s2 = new sToken();
        // mint to seller2
        address seller2 = address(0xaAAA000000000000000000000000000000000004);
        vm.prank(tempOwner);
        s2.mint(seller2, 2);

        vm.prank(seller2);
        vm.expectRevert();

        hall.createListing(2, 1 * (10 ** USDC_DECIMALS));
    }

    /* ===========================================================
       Test 5: Royalty rounding and small price handling (USDC 6 decimals)
       =========================================================== */
    function testFork_RoyaltyAndRounding_USDCDecimals() public {
        uint256 price = 1 * (10 ** USDC_DECIMALS);
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        _fundBuyerWithUSDC(buyer, 10 * (10 ** USDC_DECIMALS));
        vm.prank(buyer);
        usdc.approve(address(hall), price);

        uint256 ownerBefore = usdc.balanceOf(owner);
        uint256 sellerBefore = usdc.balanceOf(seller);

        vm.prank(buyer);
        hall.buyToken(tokenId, price);

        uint256 royalty = (price * ROYALTY_BP) / 10000; // should be integer in USDC units
        uint256 sellerShare = price - royalty;

        assertEq(usdc.balanceOf(owner), ownerBefore + royalty);
        assertEq(usdc.balanceOf(seller), sellerBefore + sellerShare);
    }

    /* ===========================================================
       Test 6: Gas measurement for buyToken (capture gas used)
       =========================================================== */
    function testFork_GasMeasurements_buyToken() public {
        uint256 price = 5 * (10 ** USDC_DECIMALS);
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        _fundBuyerWithUSDC(buyer, 100 * (10 ** USDC_DECIMALS));
        vm.prank(buyer);
        usdc.approve(address(hall), price);

        // measure gas by sending tx via a helper contract or using cheatcodes
        uint256 gasBefore = gasleft();
        vm.prank(buyer);
        hall.buyToken(tokenId, price);
        uint256 gasAfter = gasleft();
        // This is an approximate local measure — for more precise per-tx gas use foundry’s -vvvv or tx receipts.
        uint256 gasUsedApprox = gasBefore - gasAfter;
        // Emit for quick visibility in test logs (forge -vvvv will show)
        emit log_named_uint("approx gas used (local snapshot)", gasUsedApprox);
    }

    /* ===========================================================
       Test 7: Seller cannot buy own listing (explicit safety guard)
       =========================================================== */
    function testFork_SellerCannotBuyOwnListing_reverts() public {
        uint256 price = 10 * (10 ** USDC_DECIMALS);
        vm.startPrank(seller);
        stoken.approve(address(hall), tokenId);
        hall.createListing(tokenId, price);
        vm.stopPrank();

        // fund seller with USDC so they could theoretically buy their own listing
        _fundBuyerWithUSDC(seller, 100 * (10 ** USDC_DECIMALS));
        vm.prank(seller);
        usdc.approve(address(hall), price);

        // Expect a revert - replace with specific error if defined
        vm.prank(seller);
        vm.expectRevert();
        hall.buyToken(tokenId, price);
    }
}
