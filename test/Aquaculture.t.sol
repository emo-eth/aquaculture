// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "test/BaseTest.sol";
import {
    SpentItem,
    ReceivedItem,
    Schema
} from "seaport/lib/ConsiderationStructs.sol";
import { ItemType } from "seaport/lib/ConsiderationEnums.sol";
import {
    SpentItemLib, ReceivedItemLib
} from "seaport-sol/lib/SeaportStructLib.sol";
import { SeaportArrays } from "seaport-sol/lib/SeaportArrays.sol";
import { Aquaculture } from "../src/Aquaculture.sol";
import { TestERC721 } from "./helpers/TestERC721.sol";
import { TestERC1155 } from "./helpers/TestERC1155.sol";
import { ContractOffererInterface } from
    "seaport/interfaces/ContractOffererInterface.sol";

contract AquacultureTest is BaseTest {
    using SpentItemLib for SpentItem;
    using SpentItemLib for SpentItem[];
    using ReceivedItemLib for ReceivedItem;
    using ReceivedItemLib for ReceivedItem[];

    event SeaportCompatibleContractDeployed();

    Aquaculture aquaculture;
    TestERC721 erc721;
    TestERC1155 erc1155;
    address constant seaport = address(bytes20("seaport"));

    function setUp() public virtual override {
        super.setUp();
        aquaculture = new Aquaculture{value: 1 ether}(address(seaport));
    }

    function testPayableConstructor() public {
        assertEq(address(aquaculture).balance, 1 ether);
    }

    function testReceive() public {
        assertEq(address(aquaculture).balance, 1 ether);
        (bool succ,) = address(aquaculture).call{ value: 1 ether }("");
        assertTrue(succ);
        assertEq(address(aquaculture).balance, 2 ether);
    }

    function testDeployEvent() public {
        vm.expectEmit(false, false, false, false);
        emit SeaportCompatibleContractDeployed();
        new Aquaculture(address(seaport));
    }

    function testGetSeaportMetadata() public {
        (string memory name, Schema[] memory schemas) =
            aquaculture.getSeaportMetadata();
        assertEq(name, "Aquaculture");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 5);
        assertEq(schemas[0].metadata, "");
    }

    function testSupportsInterface() public {
        assertEq(aquaculture.supportsInterface(0x2e778efc), true);
        assertEq(aquaculture.supportsInterface(0x2e778efd), false);
        assertEq(
            aquaculture.supportsInterface(
                type(ContractOffererInterface).interfaceId
            ),
            true
        );
    }

    function testName() public {
        assertEq(aquaculture.name(), "Aquaculture");
    }

    function testRatifyOrder() public {
        SpentItem[] memory items;
        ReceivedItem[] memory receivedItems;
        bytes32[] memory orderIds;
        assertEq(
            aquaculture.ratifyOrder(items, receivedItems, "", orderIds, 0),
            Aquaculture.ratifyOrder.selector
        );
    }

    function testPreviewOrder_EthTo721() public {
        SpentItem[] memory minimumReceived =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
        SpentItem[] memory castMaximumSpent;
        assembly {
            castMaximumSpent := newMaximumSpent
        }
        assertEq(
            keccak256(abi.encode(minimumReceived)),
            keccak256(abi.encode(newMinimumReceived)),
            "minimumReceived not correct"
        );
        assertEq(
            keccak256(abi.encode(maximumSpent)),
            keccak256(abi.encode(castMaximumSpent)),
            "maximumSpent not correct"
        );
        assertEq(newMaximumSpent[0].recipient, address(aquaculture));
    }

    function testPreviewOrder_721toEth() public {
        SpentItem[] memory maximumSpent =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
        SpentItem[] memory castMaximumSpent;
        assembly {
            castMaximumSpent := newMaximumSpent
        }
        assertEq(
            keccak256(abi.encode(minimumReceived)),
            keccak256(abi.encode(newMinimumReceived)),
            "minimumReceived not correct"
        );
        assertEq(
            keccak256(abi.encode(maximumSpent)),
            keccak256(abi.encode(castMaximumSpent)),
            "maximumSpent not correct"
        );
        assertEq(newMaximumSpent[0].recipient, address(aquaculture));
    }

    function testPreviewOrder_InvalidNativeAmount() public {
        SpentItem[] memory maximumSpent =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(2));
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        vm.expectRevert(Aquaculture.InvalidNativeAmount.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_InvalidTokenType() public {
        SpentItem[] memory maximumSpent =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC20).withToken(
                address(1234)
            ).withAmount(1)
        );
        vm.expectRevert(Aquaculture.InvalidItemType.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_OnlyOneNativeMaxSpent() public {
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withAmount(1),
            SpentItemLib.empty().withAmount(1)
        );
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        vm.expectRevert(Aquaculture.OnlyOneNativeItem.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_OnlyOneNativeMinReceived() public {
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withAmount(1),
            SpentItemLib.empty().withAmount(1)
        );
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        vm.expectRevert(Aquaculture.OnlyOneNativeItem.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_BothNative() public {
        SpentItem[] memory minimumReceived =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory maximumSpent = minimumReceived;
        vm.expectRevert(Aquaculture.InvalidItemType.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_BothNft() public {
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        SpentItem[] memory minimumReceived = maximumSpent;
        vm.expectRevert(Aquaculture.InvalidItemType.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_MinimumReceivedEmpty() public {
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        SpentItem[] memory minimumReceived;
        vm.expectRevert(Aquaculture.MinimumReceivedCannotBeEmpty.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testPreviewOrder_MaximumSpentEmpty() public {
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        SpentItem[] memory maximumSpent;
        vm.expectRevert(Aquaculture.MaximumSpentCannotBeEmpty.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.previewOrder(
            address(0), address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testGenerateOrder_OnlySeaport() public {
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withAmount(1)
        );
        SpentItem[] memory maximumSpent = minimumReceived;
        vm.expectRevert(Aquaculture.OnlySeaport.selector);
        aquaculture.generateOrder(address(0), minimumReceived, maximumSpent, "");
    }

    function testGenerateOrder_721toEth() public {
        SpentItem[] memory maximumSpent =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        vm.prank(seaport);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.generateOrder(
            address(0), minimumReceived, maximumSpent, ""
        );
        SpentItem[] memory castMaximumSpent;
        assembly {
            castMaximumSpent := newMaximumSpent
        }
        assertEq(
            keccak256(abi.encode(minimumReceived)),
            keccak256(abi.encode(newMinimumReceived)),
            "minimumReceived not correct"
        );
        assertEq(
            keccak256(abi.encode(maximumSpent)),
            keccak256(abi.encode(castMaximumSpent)),
            "maximumSpent not correct"
        );
        assertEq(newMaximumSpent[0].recipient, address(aquaculture));
    }

    function testGenerateOrder_EthTo721() public {
        SpentItem[] memory minimumReceived =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        vm.prank(seaport);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.generateOrder(
            address(0), minimumReceived, maximumSpent, ""
        );
        SpentItem[] memory castMaximumSpent;
        assembly {
            castMaximumSpent := newMaximumSpent
        }
        assertEq(
            keccak256(abi.encode(minimumReceived)),
            keccak256(abi.encode(newMinimumReceived)),
            "minimumReceived not correct"
        );
        assertEq(
            keccak256(abi.encode(maximumSpent)),
            keccak256(abi.encode(castMaximumSpent)),
            "maximumSpent not correct"
        );
        assertEq(newMaximumSpent[0].recipient, address(aquaculture));
    }

    function testSendNativeNoReceive() public {
        aquaculture = new Aquaculture{value: 1 ether}(address(this));
        SpentItem[] memory minimumReceived =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory maximumSpent = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(1234)
            ).withIdentifier(69).withAmount(1)
        );
        vm.expectRevert(Aquaculture.NativeTransferFailed.selector);
        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.generateOrder(
            address(0), minimumReceived, maximumSpent, ""
        );
    }

    function testApproveFails() public {
        SpentItem[] memory maximumSpent =
            SeaportArrays.SpentItems(SpentItemLib.empty().withAmount(1));
        SpentItem[] memory minimumReceived = SeaportArrays.SpentItems(
            SpentItemLib.empty().withItemType(ItemType.ERC721).withToken(
                address(this)
            ).withIdentifier(69).withAmount(1)
        );
        vm.startPrank(seaport);
        vm.expectRevert(Aquaculture.TokenApprovalFailed.selector);

        (
            SpentItem[] memory newMinimumReceived,
            ReceivedItem[] memory newMaximumSpent
        ) = aquaculture.generateOrder(
            address(0), minimumReceived, maximumSpent, ""
        );
    }
}
