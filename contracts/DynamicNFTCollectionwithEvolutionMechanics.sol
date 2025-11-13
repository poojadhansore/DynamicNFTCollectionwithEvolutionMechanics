Evolution level of the NFT
        string baseURI;      Mapping from tokenId to its metadata struct
    mapping(uint256 => NFTMetadata) private _tokenMetadata;

    Initialize metadata with level 1
        _tokenMetadata[newTokenId] = NFTMetadata({
            level: 1,
            baseURI: baseURI
        });

        Example max level: 10
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
        End
End
End
End
// 
// 
End
// 
