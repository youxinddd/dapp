from web3 import Web3

# 连接节点（替换为你的节点地址）
w3 = Web3(Web3.HTTPProvider("https://carrot.megaeth.com/rpc"))

# 你的钱包地址
address = "0x29b8579C6d4D03204EC20C0b2F517D4D753b421C"

# 代币合约地址（比如你的 ERC20 代币）
token_address = "0x0Da1aa0Ae716eea6A702d76681A9aD3d4e3B3929"

# ERC20 ABI 里查询余额的部分
erc20_abi = [
    {
        "constant":True,
        "inputs":[{"name":"_owner","type":"address"}],
        "name":"balanceOf",
        "outputs":[{"name":"balance","type":"uint256"}],
        "type":"function"
    },
    {
        "constant":True,
        "inputs":[],
        "name":"decimals",
        "outputs":[{"name":"","type":"uint8"}],
        "type":"function"
    },
    {
        "constant":True,
        "inputs":[],
        "name":"symbol",
        "outputs":[{"name":"","type":"string"}],
        "type":"function"
    }
]

token_contract = w3.eth.contract(address=token_address, abi=erc20_abi)

balance = token_contract.functions.balanceOf(address).call()
decimals = token_contract.functions.decimals().call()
symbol = token_contract.functions.symbol().call()

print(f"代币余额: {balance / (10 ** decimals)} {symbol}")
