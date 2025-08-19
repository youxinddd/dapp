
from brownie import accounts, JsonStorageV1, MyProxy, Contract

def main():
    acct = accounts.load("account1")  # 你本地brownie账号名

    # 部署逻辑合约（实现合约）
    logic = JsonStorageV1.deploy({"from": acct})

    # 编码初始化调用数据
    init_data = logic.initialize.encode_input()

    # 部署代理合约，传入逻辑合约地址和初始化数据
    proxy = MyProxy.deploy(logic.address, init_data, {"from": acct})

    # 用逻辑合约 ABI 绑定代理地址，之后通过 proxy_contract 调用逻辑合约方法
    proxy_contract = Contract.from_abi("JsonStorageV1", proxy.address, JsonStorageV1.abi)

    print(f"逻辑合约地址: {logic.address}")
    print(f"代理合约地址: {proxy.address}")
    print(f"代理合约 owner: {proxy_contract.owner()}")

    # 可选：设置初始json
    initial_json = '{"name":"套你猴子","age":18,"hight":175,"weight":60,"gender":"男","address":"广东深圳","mark":"奥德彪，我是奥德彪！！","version":"1.0"}'
    tx2 = proxy_contract.setJson(initial_json, "init", {"from": acct})
    tx2.wait(1)
    print("初始化JSON数据已写入")

