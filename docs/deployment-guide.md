# Sepolia 部署指南

## 前置准备

### 1. 获取Sepolia测试ETH
- 访问 Sepolia Faucet: https://sepoliafaucet.com/
- 或使用 Alchemy Faucet: https://www.alchemy.com/faucets/ethereum-sepolia
- 需要至少 0.1 Sepolia ETH

### 2. 配置MetaMask
- 添加 Sepolia 网络（如果还没有）
  - 网络名称: Sepolia
  - RPC URL: https://sepolia.infura.io/v3/YOUR_KEY 或使用公共RPC
  - 链ID: 11155111
  - 符号: ETH
  - 浏览器: https://sepolia.etherscan.io

---

## 阶段1：部署 Stage1 Token 合约

### 步骤1.1：在Remix中编译
1. 打开 Remix IDE: https://remix.ethereum.org
2. 导入或复制 `Stage1.sol` 代码
3. 在 Solidity Compiler 页面点击 "Compile Stage1.sol"
4. 确保编译成功（无错误）

### 步骤1.2：部署合约
1. 切换到 "Deploy & Run Transactions" 页面
2. 环境选择: **Injected Provider - MetaMask**
3. 确认 MetaMask 连接到 Sepolia 网络
4. 合约选择: `Stage1`
5. 构造参数:
   - `name`: `"DiceToken"`
   - `symbol`: `"DICE"`
6. 点击 "Deploy"
7. 在 MetaMask 中确认交易

### 步骤1.3：记录部署信息
```
Stage1 合约地址: 0x________________
部署交易哈希: 0x________________
Etherscan链接: https://sepolia.etherscan.io/address/0x________________
```

---

## 阶段2：Stage1 合约交互演示

### 步骤2.1：Mint 代币
1. 在 Remix 的 "Deployed Contracts" 中展开 Stage1 合约
2. 找到 `mint` 函数
3. 参数:
   - `to`: 你的钱包地址（自动填充）
   - `value`: `1000`
4. 点击 "transact" 并在 MetaMask 确认
5. 记录交易哈希: `0x________________`

### 步骤2.2：Transfer 代币
1. 创建一个新的 MetaMask 账户作为接收方（或使用朋友的地址）
2. 调用 `transfer` 函数
3. 参数:
   - `to`: 接收方地址
   - `value`: `100`
4. 点击 "transact" 并确认
5. 记录交易哈希: `0x________________`

### 步骤2.3：Sell 代币
1. **先向合约发送ETH**:
   - 在 Remix 中，选择 "Value" 输入框
   - 输入 `30000` (wei) 或 `0.00003` (Ether)
   - 点击合约的 "receive" 按钮或直接发送
   - 确认交易
2. 调用 `sell` 函数
3. 参数:
   - `value`: `50` (出售50个代币)
4. 点击 "transact" 并确认
5. 记录交易哈希: `0x________________`

---

## 阶段3：部署 Stage2 Dice 合约

### 步骤3.1：编译 Stage2
1. 在 Remix 中打开 `Stage2.sol`
2. 编译合约

### 步骤3.2：部署合约
1. 合约选择: `Stage2`
2. 构造参数:
   - `tokenContractAddress`: Stage1 合约地址（从步骤1.3获得）
3. 点击 "Deploy"
4. 确认交易

### 步骤3.3：记录部署信息
```
Stage2 合约地址: 0x________________
部署交易哈希: 0x________________
Etherscan链接: https://sepolia.etherscan.io/address/0x________________
```

---

## 阶段4：预存 Token 奖金池

### 步骤4.1：向 Stage2 转入代币
1. 在 Stage1 合约中调用 `transfer`
2. 参数:
   - `to`: Stage2 合约地址
   - `value`: `10000` (奖金池)
3. 确认交易
4. 记录交易哈希: `0x________________`

### 步骤4.2：验证余额
1. 在 Stage1 合约中调用 `balanceOf`
2. 参数:
   - `account`: Stage2 合约地址
3. 确认返回值为 `10000`

---

## 阶段5：完整游戏演示

### 准备工作
- 需要两个 MetaMask 账户：Player A 和 Player B
- 两个账户都需要有 Sepolia ETH

### 步骤5.1：Player A 创建游戏
1. 切换到 Player A 账户
2. 准备秘密值: `"secretA123"`
3. 计算 fingerprint（在 Remix 的 Solidity Compiler 页面使用 keccak256）:
   ```
   keccak256(abi.encodePacked("secretA123"))
   ```
4. 调用 `createDiceGame`
5. 参数:
   - `_fingerPrintForA`: 上面计算的 bytes32 值
6. Value: `10000000000000000` (0.01 ETH)
7. 确认交易
8. 记录交易哈希: `0x________________`

### 步骤5.2：Player B 加入游戏
1. 切换到 Player B 账户
2. 准备秘密值: `"secretB456"`
3. 计算 fingerprint:
   ```
   keccak256(abi.encodePacked("secretB456"))
   ```
4. 调用 `joinGame`
5. 参数:
   - `_fingerPrintForB`: 上面计算的 bytes32 值
6. Value: `10000000000000000` (0.01 ETH，必须与A相同)
7. 确认交易
8. 记录交易哈希: `0x________________`

### 步骤5.3：Player A 揭示
1. 保持 Player A 账户
2. 调用 `revealA`
3. 参数:
   - `_secretA`: `keccak256(abi.encodePacked("secretA123"))`
4. 确认交易
5. 记录交易哈希: `0x________________`

### 步骤5.4：Player B 揭示
1. 切换到 Player B 账户
2. 调用 `revealB`
3. 参数:
   - `_secretB`: `keccak256(abi.encodePacked("secretB456"))`
4. 确认交易
5. 记录交易哈希: `0x________________`

### 步骤5.5：验证结算结果
1. 查看交易日志中的 `DiceGameSettled` 事件
2. 记录:
   - 随机数 n: ____
   - 获胜者地址: 0x________________
   - ETH 奖励: ____
   - Token 奖励: ____

---

## 完整交易记录表

| 操作 | 交易哈希 | 说明 |
|------|----------|------|
| Stage1 部署 | 0x________________ | Token合约部署 |
| Mint | 0x________________ | 铸造1000 DICE |
| Transfer | 0x________________ | 转账100 DICE |
| Sell | 0x________________ | 出售50 DICE |
| Stage2 部署 | 0x________________ | Dice合约部署 |
| 奖金池充值 | 0x________________ | 转入10000 DICE |
| 创建游戏 | 0x________________ | Player A创建 |
| 加入游戏 | 0x________________ | Player B加入 |
| Reveal A | 0x________________ | A揭示秘密 |
| Reveal B | 0x________________ | B揭示秘密 |

---

## 常见问题

### Q: 交易一直pending
A: Sepolia网络可能拥堵，等待或提高Gas费用

### Q: sell() 失败
A: 确保合约有足够的ETH余额，先向合约发送ETH

### Q: joinGame() 失败
A: 确保betAmount与创建游戏时相同

### Q: 如何计算keccak256
A: 在Remix的Solidity Compiler页面，展开"keccak256"工具，输入abi.encodePacked的结果
