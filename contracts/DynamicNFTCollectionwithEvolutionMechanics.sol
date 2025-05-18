// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title DynamicNFTCollectionwithEvolutionMechanics
 * @dev An NFT collection where tokens can evolve based on various mechanics
 * including age, interactions, and special events
 */
contract DynamicNFTCollectionwithEvolutionMechanics is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    
    // Evolution stages
    enum EvolutionStage { 
        EGG,        // Stage 0
        JUVENILE,   // Stage 1
        ADULT,      // Stage 2
        ELDER       // Stage 3
    }
    
    // NFT Metadata structure
    struct NFTMetadata {
        EvolutionStage stage;
        uint256 birthTimestamp;
        uint256 lastInteraction;
        uint256 interactionCount;
        uint256 evolutionPoints;
        bool isSpecial;
        string name;
    }
    
    // Mappings
    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(EvolutionStage => string) public stageBaseURIs;
    mapping(EvolutionStage => uint256) public evolutionRequirements;
    
    // Evolution events
    event Evolution(uint256 indexed tokenId, EvolutionStage from, EvolutionStage to);
    event Interaction(uint256 indexed tokenId, address indexed user, uint256 pointsGained);
    event SpecialEventTriggered(uint256 indexed tokenId, string eventType);
    
    // Constants
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant INTERACTION_COOLDOWN = 1 hours;
    uint256 public constant AGE_EVOLUTION_TIME = 7 days;
    
    constructor() ERC721("DynamicNFTCollection", "DNFT") {
        // Set evolution requirements (points needed to evolve)
        evolutionRequirements[EvolutionStage.EGG] = 0;
        evolutionRequirements[EvolutionStage.JUVENILE] = 100;
        evolutionRequirements[EvolutionStage.ADULT] = 500;
        evolutionRequirements[EvolutionStage.ELDER] = 1500;
    }
    
    /**
     * @dev Core Function 1: Mint a new dynamic NFT
     * @param to Address to mint the NFT to
     * @param name Name for the NFT
     * @return tokenId The ID of the newly minted token
     */
    function mintDynamicNFT(address to, string memory name) 
        public 
        onlyOwner 
        returns (uint256) 
    {
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        require(bytes(name).length > 0, "Name cannot be empty");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Initialize NFT metadata
        nftMetadata[tokenId] = NFTMetadata({
            stage: EvolutionStage.EGG,
            birthTimestamp: block.timestamp,
            lastInteraction: block.timestamp,
            interactionCount: 0,
            evolutionPoints: 0,
            isSpecial: false,
            name: name
        });
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
        
        return tokenId;
    }
    
    /**
     * @dev Core Function 2: Interact with NFT to gain evolution points
     * @param tokenId The ID of the token to interact with
     */
    function interactWithNFT(uint256 tokenId) 
        public 
        nonReentrant 
    {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        
        NFTMetadata storage metadata = nftMetadata[tokenId];
        require(
            block.timestamp >= metadata.lastInteraction + INTERACTION_COOLDOWN,
            "Interaction cooldown not finished"
        );
        
        // Calculate interaction points (more points for rarer interactions)
        uint256 pointsGained = _calculateInteractionPoints(tokenId);
        
        // Update metadata
        metadata.lastInteraction = block.timestamp;
        metadata.interactionCount++;
        metadata.evolutionPoints += pointsGained;
        
        // Check for evolution
        _checkAndEvolve(tokenId);
        
        emit Interaction(tokenId, msg.sender, pointsGained);
    }
    
    /**
     * @dev Core Function 3: Force evolution check and update NFT stage
     * @param tokenId The ID of the token to check for evolution
     */
    function checkEvolution(uint256 tokenId) 
        public 
    {
        require(_exists(tokenId), "Token does not exist");
        _checkAndEvolve(tokenId);
    }
    
    /**
     * @dev Internal function to check if NFT can evolve and perform evolution
     * @param tokenId The ID of the token to check
     */
    function _checkAndEvolve(uint256 tokenId) internal {
        NFTMetadata storage metadata = nftMetadata[tokenId];
        EvolutionStage currentStage = metadata.stage;
        EvolutionStage newStage = currentStage;
        
        // Check age-based evolution
        uint256 age = block.timestamp - metadata.birthTimestamp;
        if (age >= AGE_EVOLUTION_TIME && currentStage == EvolutionStage.EGG) {
            newStage = EvolutionStage.JUVENILE;
        }
        
        // Check points-based evolution
        if (metadata.evolutionPoints >= evolutionRequirements[EvolutionStage.ELDER] && 
            currentStage != EvolutionStage.ELDER) {
            newStage = EvolutionStage.ELDER;
        } else if (metadata.evolutionPoints >= evolutionRequirements[EvolutionStage.ADULT] && 
                   uint(currentStage) < uint(EvolutionStage.ADULT)) {
            newStage = EvolutionStage.ADULT;
        } else if (metadata.evolutionPoints >= evolutionRequirements[EvolutionStage.JUVENILE] && 
                   uint(currentStage) < uint(EvolutionStage.JUVENILE)) {
            newStage = EvolutionStage.JUVENILE;
        }
        
        // Check for special evolution (random chance for special NFTs)
        if (metadata.interactionCount > 50 && !metadata.isSpecial) {
            if (_generateRandomNumber(tokenId) % 100 < 5) { // 5% chance
                metadata.isSpecial = true;
                emit SpecialEventTriggered(tokenId, "Special Evolution Unlocked");
            }
        }
        
        // Perform evolution if stage changed
        if (newStage != currentStage) {
            metadata.stage = newStage;
            _setTokenURI(tokenId, _generateTokenURI(tokenId));
            emit Evolution(tokenId, currentStage, newStage);
        }
    }
    
    /**
     * @dev Calculate interaction points based on various factors
     * @param tokenId The ID of the token
     * @return points The number of points gained
     */
    function _calculateInteractionPoints(uint256 tokenId) 
        internal 
        view 
        returns (uint256 points) 
    {
        NFTMetadata memory metadata = nftMetadata[tokenId];
        
        // Base points
        points = 10;
        
        // Bonus for consecutive interactions
        if (metadata.interactionCount > 0) {
            uint256 timeSinceLastInteraction = block.timestamp - metadata.lastInteraction;
            if (timeSinceLastInteraction <= 2 * INTERACTION_COOLDOWN) {
                points += 5; // Consistency bonus
            }
        }
        
        // Stage-based multiplier
        if (metadata.stage == EvolutionStage.ELDER) {
            points = points * 150 / 100; // 1.5x multiplier for elders
        } else if (metadata.stage == EvolutionStage.ADULT) {
            points = points * 125 / 100; // 1.25x multiplier for adults
        }
        
        // Random bonus (1-20% chance for double points)
        uint256 randomBonus = _generateRandomNumber(tokenId) % 100;
        if (randomBonus < 20) {
            points *= 2;
        }
        
        return points;
    }
    
    /**
     * @dev Generate a pseudo-random number for various mechanics
     * @param seed Seed for randomization
     * @return A pseudo-random number
     */
    function _generateRandomNumber(uint256 seed) 
        internal 
        view 
        returns (uint256) 
    {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            seed,
            msg.sender
        )));
    }
    
    /**
     * @dev Generate token URI based on current metadata
     * @param tokenId The ID of the token
     * @return The generated URI string
     */
    function _generateTokenURI(uint256 tokenId) 
        internal 
        view 
        returns (string memory) 
    {
        NFTMetadata memory metadata = nftMetadata[tokenId];
        string memory baseURI = stageBaseURIs[metadata.stage];
        
        // Return stage-specific URI with special indicator if applicable
        return bytes(baseURI).length > 0 
            ? string(abi.encodePacked(
                baseURI, 
                Strings.toString(tokenId),
                metadata.isSpecial ? "_special" : "",
                ".json"
              ))
            : "";
    }
    
    /**
     * @dev Set base URIs for different evolution stages
     * @param stage The evolution stage
     * @param baseURI The base URI for that stage
     */
    function setStageBaseURI(EvolutionStage stage, string memory baseURI) 
        public 
        onlyOwner 
    {
        stageBaseURIs[stage] = baseURI;
    }
    
    /**
     * @dev Get detailed NFT information
     * @param tokenId The ID of the token
     * @return metadata The complete metadata of the NFT
     */
    function getNFTDetails(uint256 tokenId) 
        public 
        view 
        returns (NFTMetadata memory metadata) 
    {
        require(_exists(tokenId), "Token does not exist");
        return nftMetadata[tokenId];
    }
    
    /**
     * @dev Get the current age of an NFT in seconds
     * @param tokenId The ID of the token
     * @return age The age in seconds
     */
    function getNFTAge(uint256 tokenId) 
        public 
        view 
        returns (uint256 age) 
    {
        require(_exists(tokenId), "Token does not exist");
        return block.timestamp - nftMetadata[tokenId].birthTimestamp;
    }
    
    /**
     * @dev Check if NFT can be interacted with
     * @param tokenId The ID of the token
     * @return canInteract Whether the NFT can be interacted with
     */
    function canInteractWith(uint256 tokenId) 
        public 
        view 
        returns (bool canInteract) 
    {
        if (!_exists(tokenId)) return false;
        NFTMetadata memory metadata = nftMetadata[tokenId];
        return block.timestamp >= metadata.lastInteraction + INTERACTION_COOLDOWN;
    }
    
    // Override required functions
    function _burn(uint256 tokenId) 
        internal 
        override(ERC721, ERC721URIStorage) 
    {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
