// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DynamicNFTCollection is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    enum EvolutionStage { EGG, JUVENILE, ADULT, ELDER }

    struct NFTMetadata {
        EvolutionStage stage;
        uint256 birthTimestamp;
        uint256 lastInteraction;
        uint256 interactionCount;
        uint256 evolutionPoints;
        bool isSpecial;
        string name;
    }

    mapping(uint256 => NFTMetadata) public nftMetadata;
    mapping(EvolutionStage => string) public stageBaseURIs;
    mapping(EvolutionStage => uint256) public evolutionRequirements;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant INTERACTION_COOLDOWN = 1 hours;
    uint256 public constant AGE_EVOLUTION_TIME = 7 days;

    event Evolution(uint256 indexed tokenId, EvolutionStage from, EvolutionStage to);
    event Interaction(uint256 indexed tokenId, address indexed user, uint256 pointsGained);
    event SpecialEventTriggered(uint256 indexed tokenId, string eventType);
    event NameChanged(uint256 indexed tokenId, string oldName, string newName);

    constructor() ERC721("DynamicNFTCollection", "DNFT") {
        evolutionRequirements[EvolutionStage.EGG] = 0;
        evolutionRequirements[EvolutionStage.JUVENILE] = 100;
        evolutionRequirements[EvolutionStage.ADULT] = 500;
        evolutionRequirements[EvolutionStage.ELDER] = 1500;
    }

    function mintDynamicNFT(address to, string memory name) public onlyOwner returns (uint256) {
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        require(bytes(name).length > 0, "Name cannot be empty");

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

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

    function interactWithNFT(uint256 tokenId) public nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        NFTMetadata storage metadata = nftMetadata[tokenId];
        require(block.timestamp >= metadata.lastInteraction + INTERACTION_COOLDOWN, "Cooldown active");

        uint256 points = _calculateInteractionPoints(tokenId);
        metadata.lastInteraction = block.timestamp;
        metadata.interactionCount++;
        metadata.evolutionPoints += points;

        _checkAndEvolve(tokenId);
        emit Interaction(tokenId, msg.sender, points);
    }

    function resetInteractionCooldown(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        nftMetadata[tokenId].lastInteraction = 0;
    }

    function getStageName(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        EvolutionStage stage = nftMetadata[tokenId].stage;
        if (stage == EvolutionStage.EGG) return "EGG";
        if (stage == EvolutionStage.JUVENILE) return "JUVENILE";
        if (stage == EvolutionStage.ADULT) return "ADULT";
        return "ELDER";
    }

    function getOwnedTokens(address owner) public view returns (uint256[] memory) {
        uint256 total = _tokenIdCounter.current();
        uint256 count = balanceOf(owner);
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= total; i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                result[index] = i;
                index++;
            }
        }
        return result;
    }

    function safeTransferAndReset(address to, uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        _safeTransfer(msg.sender, to, tokenId, "");
        nftMetadata[tokenId].lastInteraction = block.timestamp;
    }

    function forceEvolution(uint256 tokenId, EvolutionStage newStage) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(uint(newStage) > uint(nftMetadata[tokenId].stage), "Must be higher stage");

        EvolutionStage oldStage = nftMetadata[tokenId].stage;
        nftMetadata[tokenId].stage = newStage;
        _setTokenURI(tokenId, _generateTokenURI(tokenId));

        emit Evolution(tokenId, oldStage, newStage);
    }

    function setAllStageURIs(string[4] memory uris) public onlyOwner {
        stageBaseURIs[EvolutionStage.EGG] = uris[0];
        stageBaseURIs[EvolutionStage.JUVENILE] = uris[1];
        stageBaseURIs[EvolutionStage.ADULT] = uris[2];
        stageBaseURIs[EvolutionStage.ELDER] = uris[3];
    }

    function getTotalInteractions(address user) public view returns (uint256 total) {
        uint256 totalSupply = _tokenIdCounter.current();
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (_exists(i) && ownerOf(i) == user) {
                total += nftMetadata[i].interactionCount;
            }
        }
    }

    function timeUntilNextInteraction(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        uint256 last = nftMetadata[tokenId].lastInteraction;
        if (block.timestamp >= last + INTERACTION_COOLDOWN) return 0;
        return (last + INTERACTION_COOLDOWN) - block.timestamp;
    }

    function canEvolve(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        NFTMetadata memory meta = nftMetadata[tokenId];
        if (meta.stage == EvolutionStage.ELDER) return false;
        EvolutionStage next = EvolutionStage(uint(meta.stage) + 1);
        return meta.evolutionPoints >= evolutionRequirements[next];
    }

    function _calculateInteractionPoints(uint256 tokenId) internal view returns (uint256 points) {
        NFTMetadata memory m = nftMetadata[tokenId];
        points = 10;
        if (m.interactionCount > 0 && block.timestamp - m.lastInteraction <= 2 * INTERACTION_COOLDOWN) {
            points += 5;
        }
        if (m.stage == EvolutionStage.ELDER) {
            points = (points * 150) / 100;
        } else if (m.stage == EvolutionStage.ADULT) {
            points = (points * 125) / 100;
        }
        if (_generateRandomNumber(tokenId) % 100 < 20) {
            points *= 2;
        }
        return points;
    }

    function _checkAndEvolve(uint256 tokenId) internal {
        NFTMetadata storage m = nftMetadata[tokenId];
        EvolutionStage current = m.stage;
        EvolutionStage newStage = current;

        if (block.timestamp - m.birthTimestamp >= AGE_EVOLUTION_TIME && current == EvolutionStage.EGG) {
            newStage = EvolutionStage.JUVENILE;
        }
        if (m.evolutionPoints >= evolutionRequirements[EvolutionStage.ELDER] && current != EvolutionStage.ELDER) {
            newStage = EvolutionStage.ELDER;
        } else if (m.evolutionPoints >= evolutionRequirements[EvolutionStage.ADULT] && uint(current) < uint(EvolutionStage.ADULT)) {
            newStage = EvolutionStage.ADULT;
        } else if (m.evolutionPoints >= evolutionRequirements[EvolutionStage.JUVENILE] && uint(current) < uint(EvolutionStage.JUVENILE)) {
            newStage = EvolutionStage.JUVENILE;
        }
        if (m.interactionCount > 50 && !m.isSpecial && _generateRandomNumber(tokenId) % 100 < 5) {
            m.isSpecial = true;
            emit SpecialEventTriggered(tokenId, "Special Evolution Unlocked");
        }
        if (newStage != current) {
            m.stage = newStage;
            _setTokenURI(tokenId, _generateTokenURI(tokenId));
            emit Evolution(tokenId, current, newStage);
        }
    }

    function _generateRandomNumber(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, seed, msg.sender)));
    }

    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        NFTMetadata memory m = nftMetadata[tokenId];
        string memory baseURI = stageBaseURIs[m.stage];
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, Strings.toString(tokenId), m.isSpecial ? "_special" : "", ".json"))
            : "";
    }

    // Overrides
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
// START
Updated on 2025-10-19
// END
