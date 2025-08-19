
from brownie import accounts, MegaNFTCollection

def main():
    # 部署合约  0x90b48E97826d8869E77deB5Be259FBb1A783d7f5
    dev = accounts.load("account1")
    contract = MegaNFTCollection.deploy({"from": dev})
    print(f"✅ Contract deployed at: {contract.address}")

    # 调用合约
    uris = ["https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/ttt1.json"
          ]


    tx = contract.mintBatch(dev.address, uris, {"from": dev})
    tx.wait(1)
    print("🎉 Batch mint success")