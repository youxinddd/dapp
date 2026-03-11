// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/UUPSUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/access/OwnableUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/Initializable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/token/ERC20/IERC20Upgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IMegaNFTCollection {
    function mintBatch(address to, string[] calldata uris) external;
    function nextTokenId() external view returns (uint256);
}

contract BlogPlatform is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Post {
        uint256 id;
        string title;
        string content;
        string url;
        address author;
        uint256 commentCount;
        uint256 commenterCount;
        uint256 timestamp; 
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
    uint256 public drawCost;
    uint256 public drawNonce;

    address public nftContract;

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
    mapping(address => uint256[]) private userPostIds;
    mapping(address => bool) private userIndexInitialized;

    // Authors registry for ranking
    address[] private authors;
    mapping(address => bool) public isAuthor;

    // TT redeem config and state (minimal)
    IERC20Upgradeable public ttToken; // TT token contract
    uint8 public ttDecimals; // TT token decimals
    uint256 public ttAmountPerRedeem; // TT amount per redeem (in smallest unit)
    mapping(address => uint256) public dailyRedeemCount; // today's redeem count per user
    mapping(address => uint256) public dailyRedeemDay; // the day number (block.timestamp / 1 days) for daily count
    uint256 public constant REDEEM_POINTS_COST = 50; // fixed points cost per redeem
    uint256 public constant DAILY_MAX_REDEEMS = 3; // fixed daily limit per address

    
    event PostCreated(uint256 indexed postId, address indexed author, string title);
    event Comment(address indexed commenter, uint256 indexed postId, string content, uint256 timestamp);
    event ProfileUpdated(address indexed user, string nickname);
    event PrizeAdded(string name, string uri, uint256 weight);
    event NFTDrawn(address indexed user, uint256 tokenId, string prizeName, string uri, uint256 timestamp);
    event PostEdited(uint256 indexed postId, address indexed editor);
    event TTRedeemed(address indexed user, uint256 pointsCost, uint256 amount);
    event PointsAdded(address indexed user, uint256 amount, uint256 newTotal);

    constructor() {
        _disableInitializers(); // 防止实现合约被初始化
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        drawCost = 50;
        drawNonce = 1;

        // default TT config
        ttDecimals = 18;
        ttAmountPerRedeem = 50 * (10 ** uint256(18));
    }

    function setNFTContract(address nft) external onlyOwner {
        require(nft != address(0), "invalid nft");
        nftContract = nft;
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

        require(nftContract != address(0), "NFT contract not set");

        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, drawNonce))) % totalWeight;
        uint256 cumulative = 0;
        uint256 selected = 0;

        for (uint i = 0; i < prizes.length; i++) {
            cumulative += prizes[i].weight;
            if (rand < cumulative) {
                selected = i;
                break;
            }
        }

        uint256 tokenId = IMegaNFTCollection(nftContract).nextTokenId();
        string[] memory uris = new string[](1);
        uris[0] = prizes[selected].uri;
        IMegaNFTCollection(nftContract).mintBatch(msg.sender, uris);

        emit NFTDrawn(msg.sender, tokenId, prizes[selected].name, prizes[selected].uri, block.timestamp);
        unchecked { ++drawNonce; }
    }
    
   // 积分兑换 TT
    function redeemTT() external {
        require(points[msg.sender] >= REDEEM_POINTS_COST, "Not enough points");
        require(address(ttToken) != address(0), "TT token not set");

        // Daily limit: fixed 3 times per day
        uint256 day = block.timestamp / 1 days;
        if (dailyRedeemDay[msg.sender] != day) {
            dailyRedeemDay[msg.sender] = day;
            dailyRedeemCount[msg.sender] = 0;
        }
        require(dailyRedeemCount[msg.sender] < DAILY_MAX_REDEEMS, "Redeem limit reached");

        uint256 amount = ttAmountPerRedeem;
        require(amount > 0, "Invalid TT amount");
        require(ttToken.balanceOf(address(this)) >= amount, "Insufficient TT in contract");

        // Deduct points then transfer
        points[msg.sender] -= REDEEM_POINTS_COST;
        ttToken.safeTransfer(msg.sender, amount);

        dailyRedeemCount[msg.sender] += 1;

        emit TTRedeemed(msg.sender, REDEEM_POINTS_COST, amount);
    }

    // 管理员功能 👇

    // 设置 TT 代币与小数位
    function setTTToken(address token, uint8 decimals_) external onlyOwner {
        require(token != address(0), "invalid token");
        ttToken = IERC20Upgradeable(token);
        ttDecimals = decimals_;
        ttAmountPerRedeem = 50 * (10 ** uint256(decimals_));
    }

    
    function addPoints(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "invalid user");
        require(amount > 0, "amount=0");
        points[user] += amount;
        emit PointsAdded(user, amount, points[user]);
    }

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

    // Allow contract to receive native tokens for airdrop funding
    receive() external payable {}

    // 查询功能 👇

    function getPost(uint256 postId) external view returns (Post memory) {
        return posts[postId];
    }

    function getPosts(uint256 offset, uint256 limit) external view returns (Post[] memory result) {
        if (offset >= postCount) {
            return new Post[](0);
        }
        uint256 available = postCount - offset;
        uint256 count = limit < available ? limit : available;
        result = new Post[](count);
        for (uint256 i = 0; i < count; ) {
            result[i] = posts[offset + i];
            unchecked { ++i; }
        }
    }

    function getUserPosts(address user, uint256 offset, uint256 limit) external view returns (Post[] memory result) {
        uint256[] storage ids = userPostIds[user];
        if (ids.length > 0 || userIndexInitialized[user]) {
            uint256 total = ids.length;
            if (offset >= total) return new Post[](0);
            uint256 available = total - offset;
            uint256 count = limit < available ? limit : available;
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
            return new Post[](0);
        }
        uint256 available2 = matchedCount - offset;
        uint256 returnCount = limit < available2 ? limit : available2;
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
        uint256 n = postCount;
        if (n == 0) return 0;
        address[] memory uniq = new address[](n);
        uint256 u = 0;
        for (uint256 i = 0; i < n; ) {
            address a = posts[i].author;
            bool exists = false;
            for (uint256 j = 0; j < u; ) {
                if (uniq[j] == a) { exists = true; break; }
                unchecked { ++j; }
            }
            if (!exists) {
                uniq[u] = a;
                unchecked { ++u; }
            }
            unchecked { ++i; }
        }
        return u;
    }

    // 排行榜：返回作者地址与发文数，按发文数降序，支持分页
    function getAuthorsRank(uint256 offset, uint256 limit) external view returns (address[] memory addrs, uint256[] memory counts) {
        uint256 n = postCount;
        if (n == 0) { return (new address[](0), new uint256[](0)); }

        // 收集唯一作者与对应发文数（基于 posts 统计）
        address[] memory uniq = new address[](n);
        uint256[] memory cnts = new uint256[](n);
        uint256 u = 0;
        for (uint256 i = 0; i < n; ) {
            address a = posts[i].author;
            bool found = false;
            uint256 idx = 0;
            for (uint256 j = 0; j < u; ) {
                if (uniq[j] == a) { found = true; idx = j; break; }
                unchecked { ++j; }
            }
            if (found) {
                unchecked { ++cnts[idx]; }
            } else {
                uniq[u] = a;
                cnts[u] = 1;
                unchecked { ++u; }
            }
            unchecked { ++i; }
        }

        // 仅对前 u 个元素按发文数降序排序
        for (uint256 i = 0; i < u; ) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < u; ) {
                if (cnts[j] > cnts[maxIdx]) { maxIdx = j; }
                unchecked { ++j; }
            }
            if (maxIdx != i) {
                (cnts[i], cnts[maxIdx]) = (cnts[maxIdx], cnts[i]);
                (uniq[i], uniq[maxIdx]) = (uniq[maxIdx], uniq[i]);
            }
            unchecked { ++i; }
        }

        if (offset >= u) { return (new address[](0), new uint256[](0)); }
        uint256 available = u - offset;
        uint256 m = limit < available ? limit : available;
        addrs = new address[](m);
        counts = new uint256[](m);
        for (uint256 i = 0; i < m; ) {
            addrs[i] = uniq[offset + i];
            counts[i] = cnts[offset + i];
            unchecked { ++i; }
        }
    }

}
