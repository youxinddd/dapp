from brownie import accounts,project,Contract,network
import os


# 加载当前项目（假设你在项目根目录）
p = project.load(os.getcwd())
p.load_config()

def get_nft_contract():
    network.connect("megaeth-testnet")
    contract_address = "0x90b48E97826d8869E77deB5Be259FBb1A783d7f5"
    abi = p.MegaNFTCollection.abi
    contract = Contract.from_abi("MegaNFTCollection", contract_address, abi)
    return contract


def add_nft():
    owner = accounts.load("account1") 
    uris = ["https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/ttt1.json"]
    contract = get_nft_contract() 
    # 调用 mintBatch 函数（to 地址可以是 owner 或其他人）
    tx = contract.mintBatch(owner.address, uris, {"from": owner})
    tx.wait(1)
    print("✅ NFT 批量铸造完成！")
    

def get_nft():
    user = "0x29b8579c6d4d03204ec20c0b2f517d4d753b421c"
    contract = get_nft_contract() 
    token_ids = contract.tokensOfOwner(user)

    for token_id in token_ids:
        uri = contract.tokenURI(token_id)
        owner = contract.ownerOf(token_id)

        print(f"📄 Token #{token_id} info:")
        print(f"    Owner: {owner}")
        print(f"    Metadata URI: {uri}")

add_nft()
# get_nft()