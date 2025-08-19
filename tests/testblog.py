
from brownie import accounts,project,Contract,network,web3
import os
import gzip
import base64
from io import BytesIO

# 加载当前项目（假设你在项目根目录）
p = project.load(os.getcwd())
p.load_config()



def compress_and_encode(text: str) -> str:
    # 压缩
    buf = BytesIO()
    with gzip.GzipFile(fileobj=buf, mode='wb') as f:
        f.write(text.encode('utf-8'))
    compressed_data = buf.getvalue()
    # Base64 编码
    encoded = base64.b64encode(compressed_data).decode('utf-8')
    return encoded

def decode_and_decompress(encoded_text: str) -> str:
    # Base64 解码
    compressed_data = base64.b64decode(encoded_text)
    # 解压
    buf = BytesIO(compressed_data)
    with gzip.GzipFile(fileobj=buf, mode='rb') as f:
        decompressed = f.read()
    return decompressed.decode('utf-8')


def get_contract():
    network.connect("megaeth-testnet")
    contract_address = "0x8039fec0287b01a685c851fb0Bac0Ac81694a483"
    abi = p.BlogPlatform.abi
    contract = Contract.from_abi("BlogPlatform", contract_address, abi)
    return contract
contract = get_contract() 

def clear_blog():
    owner = accounts.load("account1") 
    result = contract.clearAllPosts({"from": owner})
    print(result)


def add_blog():
    owner = accounts.load("account1") 
    content = '"内容：“碎就碎了呗，有啥大不了的？增幅失败后自我安慰，却每次都让人笑疯。不是我吹，这把肯定成！开始整活前的标志性台词，通常意味着要碎。我旭旭宝宝，增幅第一人！自信的宣言，有时是真的，有时是自我调侃。增幅这种东西，拼的是心态。碎了无数件装备后说的“心理学语录，懂？这就叫玄学！给装备喂饱、烧香拜佛等迷信操作后的总结。兄弟们，这一手，我自己都害怕！通常出现在冲击+17、+18装备前的装杯发言。这游戏策划是不是看我直播？怀疑自己被官方“针对”时的常用语。给我把音乐关了！增幅失败后气急败坏地怒关背景音乐。就这？就这！？嘲讽别的玩家或者打图太轻松时的口头禅。唉！又成了。增幅成功后的“装淡定”发言，实则内心狂喜。"'
    content = compress_and_encode(content)
    result = contract.createPost("第一届菜鸟杯子跑跑卡丁车大赛",content,"https://images.pexels.com/photos/134402/pexels-photo-134402.jpeg",{"from": owner})
    print(result)

def set_user():
    owner = accounts.load("account1") 
    result = contract.setProfile("大马猴","https://images.pexels.com/photos/33230879/pexels-photo-33230879.jpeg","描述：这是一只大马猴",{"from": owner})
    print(result)
    

def add_comment(postid,content):
    owner = accounts.load("account1") 
    result = contract.comment(postid,content,{"from": owner})
    print(result)

def get_comment(postId):
    # 准备过滤条件
    latest_block = web3.eth.block_number
    print(f"最新区块：{latest_block}")
    # 创建过滤器
    event_filter = contract.events.Comment.create_filter(
        fromBlock=latest_block-100000,
        toBlock=latest_block,
        argument_filters={
            "postId": postId
        }
    )
    # 获取日志
    logs = event_filter.get_all_entries()
    # 打印日志内容
    for log in logs:
        print({
            "commenter": log["args"]["commenter"],
            "postId": log["args"]["postId"],
            "content": log["args"]["content"],
            "timestamp": log["args"]["timestamp"]
        })

def get_prize_record(n=1):
    # 准备过滤条件
    latest_block = web3.eth.block_number
    print(f"最新区块：{latest_block}")
    logs = []
    toBlock=latest_block
    for i in range(n):
        fromBlock=toBlock-90000
        # 创建过滤器
        event_filter = contract.events.NFTDrawn.create_filter(fromBlock=fromBlock,
            toBlock=toBlock,
            argument_filters={})
        # 获取日志
        log = event_filter.get_all_entries()
        logs.extend(log)
        toBlock = fromBlock

    # 打印日志内容
    for log in logs:
        print({
            "user": log["args"]["user"],
            "tokenId": log["args"]["tokenId"],
            "prizeName": log["args"]["prizeName"]
        })

def add_prize():
    list = [("prize1","https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/prize/1.json",1),
            ("prize2","https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/prize/2.json",9),
            ("prize3","https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/prize/3.json",15),
            ("prize4","https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/prize/4.json",25),
            ("prize5","https://raw.githubusercontent.com/youxinddd/pyplist/refs/heads/main/prize/5.json",50),
            ]
    owner = accounts.load("account1") 
    for i in list:
        contract.addPrize(i[0],i[1],i[2],{"from": owner})
    print("添加完毕")

def get_prize():
    result = contract.getPrizeList()
    print(result)

def get_blog():
    # owner = accounts.load("account1") 
    # 调用 mintBatch 函数（to 地址可以是 owner 或其他人）
    result = contract.getPosts(0,10)
    print(result)
    # print(decode_and_decompress(result[0]["content"]))

def get_user_blog():
    # owner = accounts.load("account1") 
    # 调用 mintBatch 函数（to 地址可以是 owner 或其他人）
    result = contract.getUserPosts("0x29b8579C6d4D03204EC20C0b2F517D4D753b421C",0,10)
    print(result)
    # print(decode_and_decompress(result[0]["content"]))


def get_user():
    # owner = accounts.load("account1") 
    # 调用 mintBatch 函数（to 地址可以是 owner 或其他人）
    result = contract.getUserProfile("0x29b8579C6d4D03204EC20C0b2F517D4D753b421C")
    print(result)

def draw_prize():
    owner = accounts.load("account1") 
    result = contract.draw({"from": owner})
    print(result)

def get_nft():
    user = "0x29b8579c6d4d03204ec20c0b2f517d4d753b421c"
    token_ids = contract.getOwnedTokens(user)

    for token_id in token_ids:
        uri = contract.tokenURI(token_id)
        owner = contract.ownerOf(token_id)
        print(f"📄 Token #{token_id} info:")
        print(f"    Owner: {owner}")
        print(f"    Metadata URI: {uri}")

def rebuildAllUserIndexes():
    owner = accounts.load("account1")   
    contract.rebuildAllUserIndexes({"from": owner})
    print("重建完毕")


# get_prize()
# add_blog()
# add_comment(0,"大马猴，我是大马猴！我靠你娘啊！！！")
# get_comment(3)
# get_blog()
# get_user_blog()
# set_user()
# get_user()
# draw_prize()
# get_prize_record(10)
# get_nft()
rebuildAllUserIndexes()