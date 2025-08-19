from brownie import accounts, Contract, network,web3
from brownie.project import load, compile_source
import os
from web3 import Web3

# 加载当前项目（假设你在项目根目录）
project = load(os.getcwd())
project.load_config()


def get_contract():
    # 如果尚未连接网络，连接 sepolia 网络
    if not network.is_connected():
        network.connect("megaeth-testnet")
    print("当前网络:", network.show_active())

    contract_address = "0x72f5D3390649f52c57a09964FCede5F063ef7671"  # 部署后的合约地址

    # # 获取合约实例
    # import json
    # with open("./build/contracts/JsonStorageV1.json") as f:
    #     abi = json.load(f)
    #     abi = abi["abi"]  # ✅ 只取 abi
    # 
    JsonStorageV1 = project.JsonStorageV1
    abi = JsonStorageV1.abi
    json_storage = Contract.from_abi("JsonStorageV1", contract_address, abi)

    return json_storage


def test1():
    json_storage = get_contract()
    acct = accounts.load("account1")
    # # 调用 setJson()
    new_json = '{"name":"dengyouxin","age":34,"hight":175,"weight":66,"gender":"男","address":"广东深圳南山区","mark":"kao，我靠他娘啊！！","version":"1.2"}'
    action_tag = "update"
    tx_set = json_storage.setJson(new_json, action_tag, {"from": acct})
    tx_set.wait(1)
    print("JSON 已更新")

def test2(): 
    # 绑定代理合约实例（逻辑合约ABI）
    json_storage = get_contract()
    # 查询合约部署区块到最新区块
    # 准备过滤条件
    operator_address = "0x29b8579C6d4D03204EC20C0b2F517D4D753b421C"
    tag_str = "init"
    tag_bytes32 = Web3.keccak(text=tag_str)
    latest_block = web3.eth.block_number
    print(f"最新区块：{latest_block}")
    # 创建过滤器
    event_filter = json_storage.events.JsonChanged.create_filter(
        fromBlock=latest_block-100000,
        toBlock=latest_block,
        argument_filters={
            "operator": operator_address,
            # "actionTag": tag_bytes32,
        }
    )

    # 获取日志
    logs = event_filter.get_all_entries()

    # 打印日志内容
    for log in logs:
        print({
            "operator": log["args"]["operator"],
            "actionTag": log["args"]["actionTag"].hex(),
            "newJson": log["args"]["newJson"],
            "timestamp": log["args"]["timestamp"]
        })


def test3():
    # 调用getJson，无需交易费，调用view方法
    stored_json = get_contract().getJson()
    print("当前存储的JSON数据：")
    print(stored_json)


test3()