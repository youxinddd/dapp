// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/UUPSUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/access/OwnableUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/Initializable.sol";

contract BlogPlatform is Initializable, ERC721URIStorageUpgradeable, UUPSUpgradeable, OwnableUpgradeable {

    struct Post {
        uint256 id;
        string title;
        string content;
        string url;
        address author;
        uint256 commentCount;
        uint256 commenterCount;
        uint256 timestamp; // 新增：创建时间
    }


    struct Profile {
        string nickname;
        string avatar;
        string bio;
    }

    struct Prize {
        string name;
        string uri;
        uint256 weight;
    }

    uint256 public postCount;
    uint256 public tokenIdCounter;
    uint256 public drawCost;

    mapping(uint256 => Post) public posts;
    mapping(address => Profile) public profiles;
    mapping(address => uint256) public points;

    mapping(uint256 => mapping(address => bool)) public hasCommented;
    Prize[] public prizes;

    // Gas-optimized errors and constants
    error InvalidPostId();
    error NotAuthor();
    error ContentTooLong();

    uint256 public constant MAX_COMMENT_LENGTH = 1000;

    // Per-user post index for O(1) count and efficient pagination
    mapping(address => uint256[]) private userPostIds;
    // Mark users whose index has been initialized (via createPost or rebuild)
    mapping(address => bool) private userIndexInitialized;
    // tmp marker used only during rebuildAllUserIndexes to avoid repeated delete
    mapping(address => bool) private _rebuildCleared;

    // Authors registry for ranking
    address[] private authors;
    mapping(address => bool) public isAuthor;

    event PostCreated(uint256 indexed postId, address indexed author, string title);
    event Comment(address indexed commenter, uint256 indexed postId, string content, uint256 timestamp);
    event ProfileUpdated(address indexed user, string nickname);
    event PrizeAdded(string name, string uri, uint256 weight);
    event NFTDrawn(address indexed user, uint256 tokenId, string prizeName, string uri, uint256 timestamp);
    event PostEdited(uint256 indexed postId, address indexed editor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // 防止实现合约被初始化
    }

    function initialize() public initializer {
        __ERC721_init("DMHBlogNFT", "DMH");
        __ERC721URIStorage_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        drawCost = 50;
        tokenIdCounter = 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 用户功能 👇

    function createPost(string memory title, string memory content, string memory url) external {
        uint256 pid = postCount;
        posts[pid] = Post(pid, title, content, url, msg.sender, 0, 0, block.timestamp);
        unchecked { postCount = pid + 1; }
        // index by author for efficient pagination/count
        userPostIds[msg.sender].push(pid);
        userIndexInitialized[msg.sender] = true;
        if (!isAuthor[msg.sender]) {
            isAuthor[msg.sender] = true;
            authors.push(msg.sender);
        }

        points[msg.sender] += 25;
        emit PostCreated(pid, msg.sender, title);
    }

    function editPost(uint256 postId, string memory newTitle, string memory newContent, string memory newUrl) external {
        if (postId >= postCount) revert InvalidPostId();
        if (posts[postId].author != msg.sender) revert NotAuthor();

        posts[postId].title = newTitle;
        posts[postId].content = newContent;
        posts[postId].url = newUrl;
        emit PostEdited(postId, msg.sender);
    }

    function comment(uint256 postId, string memory content) external {
        if (bytes(content).length > MAX_COMMENT_LENGTH) revert ContentTooLong();
        if (postId >= postCount) revert InvalidPostId();

        posts[postId].commentCount++;

        if (!hasCommented[postId][msg.sender]) {
            posts[postId].commenterCount++;
            hasCommented[postId][msg.sender] = true;
            // 首次在该帖子评论，奖励评论者积分
            points[msg.sender] += 10;
        }

        // 非作者评论才给作者加5分
        address author = posts[postId].author;
        if (author != msg.sender) {
            points[author] += 5;
        }
        
        emit Comment(msg.sender, postId, content, block.timestamp);
    }

    function setProfile(string memory nickname, string memory avatar, string memory bio) external {
        profiles[msg.sender] = Profile(nickname, avatar, bio);
        emit ProfileUpdated(msg.sender, nickname);
    }

    function draw() external {
        require(points[msg.sender] >= drawCost, "Not enough points");
        points[msg.sender] -= drawCost;

        uint256 totalWeight = 0;
        for (uint i = 0; i < prizes.length; i++) {
            totalWeight += prizes[i].weight;
        }

        require(totalWeight > 0, "No prizes available");

        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, tokenIdCounter))) % totalWeight;
        uint256 cumulative = 0;
        uint256 selected = 0;

        for (uint i = 0; i < prizes.length; i++) {
            cumulative += prizes[i].weight;
            if (rand < cumulative) {
                selected = i;
                break;
            }
        }

        _safeMint(msg.sender, tokenIdCounter);
        _setTokenURI(tokenIdCounter, prizes[selected].uri);

        emit NFTDrawn(msg.sender, tokenIdCounter, prizes[selected].name, prizes[selected].uri, block.timestamp);
        tokenIdCounter++;
    }

    // 管理员功能 👇

    function addPrize(string memory name, string memory uri, uint256 weight) external onlyOwner {
        prizes.push(Prize(name, uri, weight));
        emit PrizeAdded(name, uri, weight);
    }

    function clearPrizes() external onlyOwner {
        delete prizes;
    }

    function clearAllPosts() external onlyOwner {
        for (uint i = 0; i < postCount; i++) {
            delete posts[i];
        }
        postCount = 0;
    }
    // 查询功能 👇

    function getPost(uint256 postId) external view returns (Post memory) {
        return posts[postId];
    }

    function getPosts(uint256 offset, uint256 limit) external view returns (Post[] memory result) {
        uint256 end = offset + limit;
        if (end > postCount) {
            end = postCount;
        }
        uint256 count = end - offset;
        result = new Post[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = posts[offset + i];
        }
    }

    function getUserPosts(address user, uint256 offset, uint256 limit) external view returns (Post[] memory result) {
        uint256[] storage ids = userPostIds[user];
        if (ids.length > 0 || userIndexInitialized[user]) {
            uint256 total = ids.length;
            if (offset >= total) return result;
            uint256 end = offset + limit;
            if (end > total) end = total;
            uint256 count = end - offset;
            result = new Post[](count);
            for (uint256 i = 0; i < count; ) {
                result[i] = posts[ids[offset + i]];
                unchecked { ++i; }
            }
            return result;
        }

        // fallback for legacy posts created before index existed
        uint256 matchedCount = 0;
        for (uint256 i = 0; i < postCount; ) {
            if (posts[i].author == user) {
                unchecked { ++matchedCount; }
            }
            unchecked { ++i; }
        }
        if (offset >= matchedCount) {
            return result;
        }
        uint256 returnCount = limit;
        if (offset + limit > matchedCount) {
            returnCount = matchedCount - offset;
        }
        result = new Post[](returnCount);
        uint256 index = 0;
        uint256 skipped = 0;
        for (uint256 i = 0; i < postCount && index < returnCount; ) {
            if (posts[i].author == user) {
                if (skipped < offset) {
                    unchecked { ++skipped; }
                } else {
                    result[index] = posts[i];
                    unchecked { ++index; }
                }
            }
            unchecked { ++i; }
        }
    }

    function getUserPostCount(address user) external view returns (uint256 count) {
        uint256 len = userPostIds[user].length;
        if (len > 0 || userIndexInitialized[user]) {
            return len;
        }
        for (uint256 i = 0; i < postCount; ) {
            if (posts[i].author == user) {
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }
    }

    // Rebuild indexes for all users from posts[]
    function rebuildAllUserIndexes() external onlyOwner returns (uint256 users, uint256 totalIndexed) {
        // reset authors list (mapping isAuthor persists to not lose historical flags; will set true again during build)
        delete authors;
        // First pass: for each post's author, clear once and mark initialized, then push postId
        for (uint256 i = 0; i < postCount; ) {
            address a = posts[i].author;
            if (!_rebuildCleared[a]) {
                delete userPostIds[a];
                _rebuildCleared[a] = true;
                userIndexInitialized[a] = true;
                if (!isAuthor[a]) { isAuthor[a] = true; }
                authors.push(a);
                unchecked { ++users; }
            }
            userPostIds[a].push(i);
            unchecked { ++totalIndexed; ++i; }
        }
        // Second pass: reset temp markers
        for (uint256 i = 0; i < postCount; ) {
            address a = posts[i].author;
            if (_rebuildCleared[a]) {
                _rebuildCleared[a] = false;
            }
            unchecked { ++i; }
        }
    }

    function getUserProfile(address user) external view returns (Profile memory, uint256 point) {
        return (profiles[user], points[user]);
    }

    function getPrizeList() external view returns (Prize[] memory) {
        return prizes;
    }

    function getTotalPosts() external view returns (uint256) {
        return postCount;
    }

    function getAuthorsTotal() external view returns (uint256) {
        return authors.length;
    }

    // 排行榜：返回作者地址与发文数，按发文数降序，支持分页
    function getAuthorsRank(uint256 offset, uint256 limit) external view returns (address[] memory addrs, uint256[] memory counts) {
        uint256 n = authors.length;
        if (offset >= n) {
            return (addrs, counts);
        }
        address[] memory a = new address[](n);
        uint256[] memory c = new uint256[](n);
        for (uint256 i = 0; i < n; ) {
            address u = authors[i];
            a[i] = u;
            uint256 len = userPostIds[u].length;
            if (len == 0 && !userIndexInitialized[u]) {
                uint256 cnt = 0;
                for (uint256 j = 0; j < postCount; ) {
                    if (posts[j].author == u) { unchecked { ++cnt; } }
                    unchecked { ++j; }
                }
                c[i] = cnt;
            } else {
                c[i] = len;
            }
            unchecked { ++i; }
        }
        // selection sort desc by count
        for (uint256 i = 0; i < n; ) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < n; ) {
                if (c[j] > c[maxIdx]) { maxIdx = j; }
                unchecked { ++j; }
            }
            if (maxIdx != i) {
                (c[i], c[maxIdx]) = (c[maxIdx], c[i]);
                (a[i], a[maxIdx]) = (a[maxIdx], a[i]);
            }
            unchecked { ++i; }
        }
        uint256 end = offset + limit;
        if (end > n) end = n;
        uint256 m = end - offset;
        addrs = new address[](m);
        counts = new uint256[](m);
        for (uint256 i = 0; i < m; ) {
            addrs[i] = a[offset + i];
            counts[i] = c[offset + i];
            unchecked { ++i; }
        }
    }

    function getOwnedTokens(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 index = 0;

        for (uint256 tokenId = 1; tokenId < tokenIdCounter; tokenId++) {
            if (_exists(tokenId) && ownerOf(tokenId) == owner) {
                tokenIds[index] = tokenId;
                index++;
                if (index == balance) break;
            }
        }
        
        return tokenIds;
    }
}
