// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./sol2.sol";

contract DataToken is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    sol2 public sol;

    struct TRANSACTIONDATA{
        uint256 _amount;
        uint256 _interestRate;
        uint256 _collateralFactor;
        uint256 _poolId;
    }

    mapping (uint=>uint) public NftIdToAmount;
    TRANSACTIONDATA [] public liquidityTransactions;
    mapping (uint=>TRANSACTIONDATA []) public NtfToData;

    constructor() ERC721("MyToken", "MTK") {}

    function safeMint(address to, uint256 tokenId,  uint256 amount, uint256 interestRate, uint256 collateralFactor, uint256 poolId) public  {
        _safeMint(to, tokenId);
        liquidityTransactions.push(TRANSACTIONDATA({_amount:amount, _interestRate:interestRate,_collateralFactor:collateralFactor, _poolId:poolId}));
        TRANSACTIONDATA [] storage data= NtfToData[poolId];
        data.push(TRANSACTIONDATA({_amount:amount, _interestRate:interestRate,_collateralFactor:collateralFactor, _poolId:poolId}));
        NftIdToAmount[tokenId]=amount;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
