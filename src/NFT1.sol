//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract Nft1 is ERC721 {
    uint public tokenId;
    constructor()
        ERC721("", "")
        
    {}

    function safeMint(address _to) public  {
        _safeMint(_to, tokenId);
        tokenId++;
    }
}
