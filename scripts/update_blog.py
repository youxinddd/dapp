import os
import json
from pathlib import Path

from brownie import accounts, web3


DEFAULT_PROXY = "0xe2bCF79E7EDF3f1BA90b7160e8775De942E362d5"


def _artifact(name: str) -> dict:
    path = Path("build") / "contracts" / f"{name}.json"
    return json.loads(path.read_text())


def _get_private_key(acct):
    pk = getattr(acct, "private_key", None)
    if pk:
        return pk
    env_pk = os.getenv("BROWNIE_PRIVATE_KEY")
    if env_pk:
        return env_pk
    raise ValueError("Cannot access private key. Set env BROWNIE_PRIVATE_KEY to upgrade via raw web3.")


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

    # ensure no legacy gasPrice conflicts with type-2
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

    proxy_addr = os.getenv("BLOG_PROXY_ADDRESS", DEFAULT_PROXY)

    blog_art = _artifact("BlogPlatform")

    # sanity checks (lightweight eth_call, should not hit 60M cap)
    owner = _call_view(proxy_addr, blog_art["abi"], "owner", [])
    if owner.lower() != acct.address.lower():
        raise ValueError(f"Proxy owner is {owner}, but signer is {acct.address}. Upgrade would revert.")

    # 1) Deploy new BlogPlatform implementation (logic)
    new_logic = _raw_deploy(acct, "BlogPlatform", [], pk)
    print(f"New BlogPlatform implementation deployed: {new_logic}")

    # 2) UUPS upgrade: call upgradeTo(newImplementation) on the proxy
    receipt = _call(acct, proxy_addr, blog_art["abi"], "upgradeTo", [new_logic], pk)
    print(f"Upgrade tx status: {receipt.status}, tx: {receipt.transactionHash.hex()}")
    print("✅ Upgrade complete")
