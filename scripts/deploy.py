from brownie import MyToken, accounts

def main():
    acct = accounts.load("my_account")  # 加载你的账户
    MyToken.deploy(1_000_000, {"from": acct})