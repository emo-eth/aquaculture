# Aquaculture

Aquaculture is a simple, proof-of-concept [SIP-5 Seaport contract offerer](https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-5.md) that will pay 1 wei for any ERC721 token or any amount of a particular ERC1155 token ID, and will likewise sell any token it owns for 1 wei.

Aquaculture makes the following enforcements
- one of the `minimumReceived` or `maximumSpent` arrays must contain only `SpentItem`s with `itemType`s equal to `ERC721` or `ERC1155` 
- the other array must only contain a single `SpentItem` with an `itemType` equal to `NATIVE`, and an `amount` equal to the length of the other array

In other words:
- Aquaculture will give or receive 1 wei for each individual `SpentItem` in the complementary array
- Aquaculture will only pay/receive 1 wei for any number of ERC1155 tokens specified by a `SpentItem`

