// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DynamicNFTCollectionWithEvolutionMechanics
 * @dev ERC721-like dynamic NFT collection with level-based evolution and updatable metadata URI
 * @notice Tokens can gain XP, level up, and change their tokenURI based on evolution rules
 */
interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

contract DynamicNFTCollectionWithEvolutionMechanics {
    // Basic ERC721 storage
    string public name;
    string public symbol;
    address public owner;

    // tokenId => owner
    mapping(uint256 => address) private _owners;
    // owner => balance
    mapping(address => uint256) private _balances;
    // tokenId => approved
    mapping(uint256 => address) private _tokenApprovals;
    // owner => operator => approved
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Evolution mechanics
    struct EvolutionState {
        uint256 level;
        uint256 xp;
        string  baseURI;    // base URI for this token's current form
        bool    locked;     // if true, cannot evolve further
    }

    // tokenId => EvolutionState
    mapping(uint256 => EvolutionState) public evolutionOf;

    // Global config
    uint256 public nextTokenId;
    uint256 public xpPerAction;          // XP granted per gainXp call
    uint256 public xpPerLevel;           // XP required to increase one level
    uint256 public maxLevel;             // cap for levels

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event XpGained(uint256 indexed tokenId, uint256 newXp);
    event LeveledUp(uint256 indexed tokenId, uint256 newLevel);
    event BaseURIUpdated(uint256 indexed tokenId, string newBaseURI);
    event EvolutionLocked(uint256 indexed tokenId, bool locked);
    event ParamsUpdated(uint256 xpPerAction, uint256 xpPerLevel, uint256 maxLevel);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _xpPerAction,
        uint256 _xpPerLevel,
        uint256 _maxLevel
    ) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        xpPerAction = _xpPerAction;
        xpPerLevel = _xpPerLevel;
        maxLevel = _maxLevel;
    }

    // ============ ERC721 core ============

    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view tokenExists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function approve(address to, uint256 tokenId) external tokenExists(tokenId) {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender), "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view tokenExists(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "Self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _owners[tokenId];
        return (
            spender == tokenOwner ||
            spender == getApproved(tokenId) ||
            isApprovedForAll(tokenOwner, spender)
        );
    }

    function transferFrom(address from, address to, uint256 tokenId) public tokenExists(tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        require(_owners[tokenId] == from, "Wrong from");
        require(to != address(0), "Zero to");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "Non ERC721Receiver");
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(_owners[tokenId], to, tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data)
        private
        returns (bool)
    {
        if (to.code.length == 0) {
            return true;
        }
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }

    // ============ Minting & Evolution ============

    /**
     * @dev Mint a new NFT with initial evolution state
     * @param to Recipient
     * @param baseURI Initial base URI
     */
    function mint(address to, string calldata baseURI) external onlyOwner returns (uint256 tokenId) {
        require(to != address(0), "Zero to");

        tokenId = nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;

        evolutionOf[tokenId] = EvolutionState({
            level: 1,
            xp: 0,
            baseURI: baseURI,
            locked: false
        });

        emit Transfer(address(0), to, tokenId);
        emit BaseURIUpdated(tokenId, baseURI);
    }

    /**
     * @dev Grant XP to a token and auto-level if thresholds are crossed
     */
    function gainXp(uint256 tokenId, uint256 times)
        external
        tokenExists(tokenId)
    {
        require(times > 0, "Times = 0");
        require(_isApprovedOrOwner(msg.sender, tokenId) || msg.sender == owner, "Not authorized");

        EvolutionState storage e = evolutionOf[tokenId];
        require(!e.locked, "Evolution locked");

        uint256 addedXp = xpPerAction * times;
        e.xp += addedXp;

        emit XpGained(tokenId, e.xp);

        // handle level ups
        while (e.level < maxLevel && e.xp >= e.level * xpPerLevel) {
            e.level += 1;
            emit LeveledUp(tokenId, e.level);
        }
    }

    /**
     * @dev Owner can update baseURI when evolution milestone is reached (e.g., new level)
     */
    function updateBaseURI(uint256 tokenId, string calldata newBaseURI)
        external
        tokenExists(tokenId)
    {
        require(_isApprovedOrOwner(msg.sender, tokenId) || msg.sender == owner, "Not authorized");
        EvolutionState storage e = evolutionOf[tokenId];
        require(!e.locked, "Locked");
        e.baseURI = newBaseURI;
        emit BaseURIUpdated(tokenId, newBaseURI);
    }

    /**
     * @dev Lock or unlock further evolution of a token
     */
    function setEvolutionLocked(uint256 tokenId, bool locked)
        external
        tokenExists(tokenId)
    {
        require(_isApprovedOrOwner(msg.sender, tokenId) || msg.sender == owner, "Not authorized");
        evolutionOf[tokenId].locked = locked;
        emit EvolutionLocked(tokenId, locked);
    }

    /**
     * @dev tokenURI view combining baseURI and level (off-chain renderer interprets this)
     */
    function tokenURI(uint256 tokenId) external view tokenExists(tokenId) returns (string memory) {
        EvolutionState memory e = evolutionOf[tokenId];
        // Simple pattern: baseURI is already full URI; advanced: append level or query param
        return e.baseURI;
    }

    // ============ Admin config ============

    function updateParams(uint256 _xpPerAction, uint256 _xpPerLevel, uint256 _maxLevel)
        external
        onlyOwner
    {
        xpPerAction = _xpPerAction;
        xpPerLevel = _xpPerLevel;
        maxLevel = _maxLevel;
        emit ParamsUpdated(_xpPerAction, _xpPerLevel, _maxLevel);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
