
from brownie import accounts,BlogPlatform, MyProxy, Contract

def main():
    acct = accounts.load("account1")

    # 1. 部署实现
    logic = BlogPlatform.deploy({"from": acct})

    # 2. 初始化数据
    init_data = logic.initialize.encode_input()

    # 3. 部署代理（符合EIP-1967标准）  0x8039fec0287b01a685c851fb0Bac0Ac81694a483
    proxy = MyProxy.deploy(
        logic.address,
        init_data,
        {"from": acct}
    )

    proxy_contract = Contract.from_abi("BlogPlatform", proxy.address, BlogPlatform.abi)
    print(f"逻辑合约地址: {logic.address}")
    print(f"代理合约地址: {proxy.address}")
    print(f"代理合约 owner: {proxy_contract.owner()}")
    print("部署成功！！")