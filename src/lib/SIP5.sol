// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC165 } from "forge-std/interfaces/IERC165.sol";
import { Schema } from "seaport/lib/ConsiderationStructs.sol";
import { ContractOffererInterface } from
    "seaport/interfaces/ContractOffererInterface.sol";

abstract contract SIP5 is ContractOffererInterface, IERC165 {
    /**
     * @dev An event that is emitted when a SIP-5 compatible contract is
     * deployed.
     */
    event SeaportCompatibleContractDeployed();

    constructor() {
        emit SeaportCompatibleContractDeployed();
    }

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name_    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        virtual
        returns (string memory name_, Schema[] memory schemas)
    {
        schemas = new Schema[](1);
        schemas[0] = Schema({ id: 5, metadata: "" });
        return (name(), schemas);
    }

    function supportsInterface(bytes4 id)
        external
        pure
        virtual
        returns (bool)
    {
        return
            id == 0x2e778efc || id == type(ContractOffererInterface).interfaceId;
    }

    function name() public pure virtual returns (string memory);
}
