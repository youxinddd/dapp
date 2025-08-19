// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/Initializable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/proxy/utils/UUPSUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.9.3/contracts/access/OwnableUpgradeable.sol";

contract JsonStorageV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    string private jsonData;

    // 事件：操作人，操作标签，最新json，区块时间戳
    event JsonChanged(
        address indexed operator,
        bytes32 indexed actionTag,
        string newJson,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // 初始化函数，必须调用
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @notice 设置JSON数据
     * @param newJson 新的JSON字符串
     * @param action 操作标签，如 "update"
     */
    function setJson(string calldata newJson, string calldata action) external onlyOwner {
        require(bytes(newJson).length <= 2000, "JsonStorageV1: JSON too long"); // 限制长度避免gas爆炸

        jsonData = newJson;

        bytes32 tag = keccak256(abi.encodePacked(action));
        emit JsonChanged(msg.sender, tag, newJson, block.timestamp);
    }

    /// @notice 获取存储的JSON字符串
    function getJson() external view returns (string memory) {
        return jsonData;
    }

    /// @notice 获取存储的JSON字符串长度，便于链下快速判断
    function getJsonLength() external view returns (uint256) {
        return bytes(jsonData).length;
    }

    /// @notice 当前版本号
    function version() external pure returns (string memory) {
        return "v1.0.1";
    }

    // 仅owner可升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
