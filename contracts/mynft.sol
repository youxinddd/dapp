// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts@4.9.3/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "OpenZeppelin/openzeppelin-contracts@4.9.3/contracts/access/Ownable.sol";

contract MegaNFTCollection is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    constructor() ERC721("DMH NFT Collection", "DMH") {}

    /**
     * 批量铸造 NFT，每个 NFT 指定一个唯一的 tokenURI（通常指向 IPFS metadata）
     * 只能由合约拥有者执行
     */
    function mintBatch(address to, string[] calldata uris) external onlyOwner {
        require(uris.length > 0, "No URIs provided");

        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = nextTokenId;
            _mint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
            nextTokenId++;
        }
    }

    /**
     * 查询某个地址拥有的所有 NFT tokenId（可选辅助函数）
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory result = new uint256[](balance);
        uint256 count = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ownerOf(i) == owner) {
                result[count] = i;
                count++;
            }
        }
        return result;
    }
}
