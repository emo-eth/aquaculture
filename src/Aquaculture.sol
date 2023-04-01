// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    SpentItem,
    ReceivedItem,
    Schema
} from "seaport/lib/ConsiderationStructs.sol";
import { ItemType } from "seaport/lib/ConsiderationEnums.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";
import { SIP5 } from "./lib/SIP5.sol";


/**
 * @title Aquaculture
 * @author emo.eth
 * @notice Aquaculture is a simple, proof-of-concept SIP-5 Seaport contract
 * offerer that will pay 1 wei for any ERC721 token or any amount of a particular
 * ERC1155 tokenId, and will likewise sell any token it owns for 1 wei.
 */
contract Aquaculture is SIP5 {
    error InvalidItemType();
    error MinimumReceivedCannotBeEmpty();
    error MaximumSpentCannotBeEmpty();
    error OnlyOneNativeItem();
    error InvalidNativeAmount();
    error OnlySeaport();
    error TokenApprovalFailed();
    error NativeTransferFailed();

    string constant _name = "Aquaculture";
    address immutable SEAPORT;

    constructor(address seaport) payable {
        SEAPORT = seaport;
    }

    /**
     * @dev Allows the contract to receive native tokens.
     */
    receive() external payable { }

    function name() public pure override returns (string memory) {
        return _name;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function generateOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        if (msg.sender != SEAPORT) {
            revert OnlySeaport();
        }

        (bool minReceivedNative, uint256 nativeAmount) =
            _validateItems(minimumReceived, maximumSpent);
        // if minimum received is native token, then send native token back to
        // seaport
        if (minReceivedNative) {
            _sendNative(nativeAmount);
        } else {
            // otherwise approve token contract
            _approveMinReceived(minimumReceived);
        }
        return (minimumReceived, _toReceivedItems(maximumSpent));
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     *
     * @return ratifyOrderMagicValue The magic value returned by the contract
     *                               offerer.
     */
    function ratifyOrder(
        SpentItem[] calldata,
        ReceivedItem[] calldata,
        bytes calldata,
        bytes32[] calldata,
        uint256
    ) external pure returns (bytes4 ratifyOrderMagicValue) {
        return this.ratifyOrder.selector;
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     *
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata // encoded based on the schemaID
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        _validateItems(minimumReceived, maximumSpent);
        return (minimumReceived, _toReceivedItems(maximumSpent));
    }

    /**
     * @dev validate the minimumReceived and maximumSpent items, namely:
     * - only allow native <-> nft swaps
     * - only allow 1 native item with amount equal to number of nft swaps
     * - validate all nft items are ERC721 or ERC1155
     * - there is at least one item in each array
     */
    function _validateItems(
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent
    ) internal pure returns (bool minReceivedNative, uint256 nativeAmount) {
        if (minimumReceived.length == 0) {
            revert MinimumReceivedCannotBeEmpty();
        }
        if (maximumSpent.length == 0) {
            revert MaximumSpentCannotBeEmpty();
        }
        minReceivedNative = minimumReceived[0].itemType == ItemType.NATIVE;
        bool maxSpentNative = maximumSpent[0].itemType == ItemType.NATIVE;

        // only allow native<->nfts
        if (!(minReceivedNative || maxSpentNative)) {
            revert InvalidItemType();
        } else if (minReceivedNative && maxSpentNative) {
            revert InvalidItemType();
        }
        // only allow one native item
        if (minReceivedNative) {
            if (minimumReceived.length > 1) {
                revert OnlyOneNativeItem();
            }
            nativeAmount = minimumReceived[0].amount;
            // 1 wei per item
            _validateNativeAmount(nativeAmount, maximumSpent.length);
            // validate all are ERC721 or ERC1155
            _validateSpentItems(maximumSpent);
        } else {
            if (maximumSpent.length > 1) {
                revert OnlyOneNativeItem();
            }
            nativeAmount = maximumSpent[0].amount;
            // 1 wei per item
            _validateNativeAmount(nativeAmount, minimumReceived.length);
            // validate all are ERC721 or ERC1155
            _validateSpentItems(minimumReceived);
        }

        return (minReceivedNative, nativeAmount);
    }

    /**
     * @dev convert the spent items to received items
     */
    function _toReceivedItems(SpentItem[] calldata items)
        internal
        view
        returns (ReceivedItem[] memory receivedItems)
    {
        uint256 itemsLength = items.length;
        receivedItems = new ReceivedItem[](itemsLength);
        for (uint256 i = 0; i < itemsLength;) {
            SpentItem memory item = items[i];
            receivedItems[i] = ReceivedItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifier,
                amount: item.amount,
                recipient: payable(this)
            });
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev validate an item is either ERC721 or ERC1155
     */
    function _validateSpentItem(SpentItem calldata item) internal pure {
        ItemType itemType = item.itemType;
        if (itemType != ItemType.ERC721 && itemType != ItemType.ERC1155) {
            revert InvalidItemType();
        }
    }

    /**
     * @dev validate all items are either ERC721 or ERC1155
     */
    function _validateSpentItems(SpentItem[] calldata items) internal pure {
        uint256 itemsLength = items.length;
        for (uint256 i = 0; i < itemsLength;) {
            _validateSpentItem(items[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev when minimumReceived items are NFTs, approve each contract to
     * transfer
     */
    function _approveMinReceived(SpentItem[] calldata items) internal {
        // re-use approval calldata so new memory is not allocated each time
        bytes memory callData =
            abi.encodeCall(IERC721.setApprovalForAll, (msg.sender, true));
        // cache length and start of callData
        uint256 callDataLength = 0x44;
        uint256 callDataStart;
        assembly {
            callDataStart := add(callData, 0x20)
        }
        uint256 itemsLength = items.length;
        for (uint256 i = 0; i < itemsLength;) {
            SpentItem calldata item = items[i];
            address token = item.token;
            bool success;
            assembly {
                success :=
                    call(gas(), token, 0, callDataStart, callDataLength, 0, 0)
            }
            if (!success) {
                revert TokenApprovalFailed();
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev send native token to seaport
     */
    function _sendNative(uint256 amount) internal {
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) {
            revert NativeTransferFailed();
        }
    }

    /**
     * @dev enforce 1 wei per item (but not per amount)
     */
    function _validateNativeAmount(uint256 length, uint256 value)
        internal
        pure
    {
        if (length != value) {
            revert InvalidNativeAmount();
        }
    }
}
