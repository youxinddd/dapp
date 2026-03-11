
import os
import json
from pathlib import Path

from brownie import accounts, web3


def _artifact(name: str) -> dict:
    path = Path("build") / "contracts" / f"{name}.json"
    return json.loads(path.read_text())


def _get_private_key(acct):
    # Brownie LocalAccount usually exposes .private_key; fall back to env var
    pk = getattr(acct, "private_key", None)
    if pk:
        return pk
    env_pk = os.getenv("BROWNIE_PRIVATE_KEY")
    if env_pk:
        return env_pk
    raise ValueError("Cannot access private key. Set env BROWNIE_PRIVATE_KEY to deploy via raw web3.")


def _fee_fields() -> dict:
    blk = web3.eth.get_block("latest")
    base = int(blk.get("baseFeePerGas", 0))
    tip = 1_000_000  # 0.001 gwei
    max_fee = base * 2 + tip
    return {"maxFeePerGas": max_fee, "maxPriorityFeePerGas": tip, "type": 2}


def _send_signed(acct, tx: dict, pk):
    tx = dict(tx)
    tx.setdefault("chainId", web3.eth.chain_id)
    tx.setdefault("nonce", web3.eth.get_transaction_count(acct.address))
    tx.setdefault("value", 0)
    tx.update(_fee_fields())

    # build_transaction may include legacy gasPrice; remove it for type-2 tx
    tx.pop("gasPrice", None)

    if "gas" not in tx:
        est = web3.eth.estimate_gas(tx)
        tx["gas"] = int(est * 1.15)

    signed = web3.eth.account.sign_transaction(tx, pk)
    raw = getattr(signed, "rawTransaction", None)
    if raw is None:
        raw = signed.raw_transaction
    tx_hash = web3.eth.send_raw_transaction(raw)
    receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
    return receipt


def _raw_deploy(acct, contract_name: str, args: list, pk):
    art = _artifact(contract_name)
    abi = art["abi"]
    bytecode = art["bytecode"]
    if not bytecode.startswith("0x"):
        bytecode = "0x" + bytecode
    contract = web3.eth.contract(abi=abi, bytecode=bytecode)
    tx = contract.constructor(*args).build_transaction({"from": acct.address})
    receipt = _send_signed(acct, tx, pk)
    if not receipt.contractAddress:
        raise ValueError(f"Deploy failed for {contract_name}: no contractAddress")
    return receipt.contractAddress


def _call(acct, to: str, abi: list, fn: str, args: list, pk):
    c = web3.eth.contract(address=to, abi=abi)
    tx = c.functions[fn](*args).build_transaction({"from": acct.address})
    return _send_signed(acct, tx, pk)


def _call_view(to: str, abi: list, fn: str, args: list):
    c = web3.eth.contract(address=to, abi=abi)
    return c.functions[fn](*args).call()


def main():
    acct = accounts.load("account1")
    pk = _get_private_key(acct)

    blog_art = _artifact("BlogPlatform")
    proxy_art = _artifact("MyProxy")
    nft_art = _artifact("MegaNFTCollection")
    tt_art = _artifact("MyToken")

    # 1) Deploy BlogPlatform implementation (logic)
    logic_addr = _raw_deploy(acct, "BlogPlatform", [], pk)
    print(f"逻辑合约地址: {logic_addr}")

    # 2) Encode initialize() call for proxy constructor
    init_data = web3.eth.contract(abi=blog_art["abi"]).encodeABI(fn_name="initialize", args=[])

    # 3) Deploy MyProxy(logic, init_data)
    proxy_addr = _raw_deploy(acct, "MyProxy", [logic_addr, bytes.fromhex(init_data[2:])], pk)
    print(f"代理合约地址: {proxy_addr}")

    # 4) Deploy NFT contract
    nft_addr = _raw_deploy(acct, "MegaNFTCollection", [], pk)
    print(f"✅ NFT Contract deployed at: {nft_addr}")

    # Transfer NFT ownership to proxy and bind in BlogPlatform
    _call(acct, nft_addr, nft_art["abi"], "transferOwnership", [proxy_addr], pk)
    _call(acct, proxy_addr, blog_art["abi"], "setNFTContract", [nft_addr], pk)
    print("✅ NFT ownership transferred and bound to BlogPlatform")

    # 5) Deploy TT token and bind to BlogPlatform, then fund proxy with TT
    tt_addr = _raw_deploy(acct, "MyToken", [1_000_000], pk)
    decimals = _call_view(tt_addr, tt_art["abi"], "decimals", [])
    _call(acct, proxy_addr, blog_art["abi"], "setTTToken", [tt_addr, int(decimals)], pk)
    fund_amount = 500_000 * (10 ** int(decimals))
    _call(acct, tt_addr, tt_art["abi"], "transfer", [proxy_addr, fund_amount], pk)
    print(f"✅ TT deployed at: {tt_addr}")
    print(f"✅ Funded BlogPlatform with TT: {fund_amount}")

    # 6) Seed prize pool
    prize_list = [
        ("惊恐猫", "ipfs://QmXddfFBpWTZjA5YjB6P3dLTxTESr97iaRDPByakyY797V", 10),
        ("暗黑鲲", "ipfs://QmPZor53ZukMihxcnWx2Vnr1L9qDYmR26A6XG9WsXYtLp5", 5),
        ("大马猩", "ipfs://QmQXiTtTembcXPptU8TWxEjpr9hnPEJTTvDyiA2GvLU2uP", 15),
        ("暴恐龙", "ipfs://QmZiKyKujgZNVLzGa1aFXuertUThMdafL2zAXPF6fArLfe", 5),
        ("小屁猴", "ipfs://QmYYNuAqX5nyUsezc1cGgXEi8retEzjhLpa5cBWUva9AtJ", 15),
        ("萝莉马", "ipfs://QmTqe3subbkYPEcfSEQvhJDDJewTSUwoJ74zRJBUS8bBHe", 10),
        ("蓝影邪龙", "ipfs://QmcfEqMfjFvwRzDN4okTC6u2EysRzr9Me5G9Pa9ntJff2J", 5),
        ("卖报兔", "ipfs://QmeWDUWavgsvnZRfyUaKjfhpdc6GHckJZ8ywMHQqps2jY3", 10),
        ("小奶虎", "ipfs://QmfMrUgR92PFziRQVquhmLZqgyRgUpFkBQQvTQrn7PjufW", 15),
    ]
    for name, uri, weight in prize_list:
        _call(acct, proxy_addr, blog_art["abi"], "addPrize", [name, uri, weight], pk)
    print("✅ Prize pool initialized")

    # Summary
    print("\n=== Summary ===")
    print(f"BlogPlatform logic: {logic_addr}")
    print(f"BlogPlatform proxy: {proxy_addr}")
    print(f"NFT: {nft_addr}")
    print(f"TT: {tt_addr}")

