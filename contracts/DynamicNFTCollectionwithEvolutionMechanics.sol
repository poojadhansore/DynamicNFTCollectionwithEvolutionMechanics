// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DynamicNFTCollectionWithEvolution
 * @dev ERC721 NFT with evolution mechanics allowing token owners to evolve NFTs,
 * increasing their level and updating metadata URI accordingly.
 */
contract DynamicNFTCollectionWithEvolution is ERC721URIStorage, Ownable {
    struct NFTMetadata {
        uint256 level;       // Evolution level of the NFT
        string baseURI;      // Base URI for metadata
    }

    // Mapping from tokenId to its metadata struct
    mapping(uint256 => NFTMetadata) private _tokenMetadata;

    // Event emitted when an NFT evolves
    event Evoluted(uint256 indexed tokenId, uint256 newLevel);

    uint256 private _tokenCounter;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _tokenCounter = 0;
    }

    /**
     * @dev Mints a new NFT to `to` with initial baseURI and level=1
     */
    function mintNFT(address to, string memory baseURI) external onlyOwner returns (uint256) {
        _tokenCounter++;
        uint256 newTokenId = _tokenCounter;

        _safeMint(to, newTokenId);

        // Initialize metadata with level 1
        _tokenMetadata[newTokenId] = NFTMetadata({
            level: 1,
            baseURI: baseURI
        });

        // Set token URI to baseURI + level info
        string memory tokenURI_ = _constructTokenURI(newTokenId);
        _setTokenURI(newTokenId, tokenURI_);

        return newTokenId;
    }

    /**
     * @dev Allows the token owner to evolve (level up) their NFT.
     * Increments the level and updates the token URI metadata accordingly.
     */
    function evolveNFT(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the token owner");

        NFTMetadata storage metadata = _tokenMetadata[tokenId];

        // Example max level: 10
        require(metadata.level < 10, "Max evolution level reached");

        metadata.level += 1;

        string memory updatedTokenURI = _constructTokenURI(tokenId);
        _setTokenURI(tokenId, updatedTokenURI);

        emit Evoluted(tokenId, metadata.level);
    }

    /**
     * @dev Returns the current evolution level of a token
     */
    function getNFTLevel(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Query for nonexistent token");
        return _tokenMetadata[tokenId].level;
    }

    /**
     * @dev Override tokenURI to provide dynamic URI based on baseURI and level
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Constructs the token URI string reflecting current evolution level
     * Example might append "?level=X" or "/levelX.json" etc.
     */
    function _constructTokenURI(uint256 tokenId) internal view returns (string memory) {
        NFTMetadata memory metadata = _tokenMetadata[tokenId];
        // Example: concatenate baseURI with "/levelX.json"
        return string(abi.encodePacked(metadata.baseURI, "/level", _uint2str(metadata.level), ".json"));
    }

    /**
     * @dev Helper function: uint to string conversion
     */
    function _uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        str = string(bstr);
    }
}
