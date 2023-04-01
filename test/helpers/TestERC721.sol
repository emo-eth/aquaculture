// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC721 } from "openzeppelin-contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721("test", "test") {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
