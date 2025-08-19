
from brownie import accounts, BlogPlatform, Contract

def main():
    acct = accounts.load("account1")

    # 1. 部署实现
    logic = BlogPlatform.deploy({"from": acct})

    # 2. 初始化数据
    init_data = logic.initialize.encode_input()

    # 3. 部署代理（符合EIP-1967标准）  
    proxy_address = "0x8039fec0287b01a685c851fb0Bac0Ac81694a483"
    proxy_contract = Contract.from_abi("BlogPlatform", proxy_address, BlogPlatform.abi)
    proxy_contract.upgradeTo(logic.address, {"from": acct})  
    print("升级成功！")