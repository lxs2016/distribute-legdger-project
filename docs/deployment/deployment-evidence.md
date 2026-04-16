# Sepolia 部署证据

## Stage 1 Token 合约

- **合约地址**: `0x________________`
- **部署交易**: `0x________________`
- **Etherscan链接**: https://sepolia.etherscan.io/address/0x________________

### 交互记录

#### 1. Mint 操作
- **交易哈希**: `0x________________`
- **说明**: 铸造 1000 DICE tokens 到部署者地址
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 2. Transfer 操作
- **交易哈希**: `0x________________`
- **说明**: 转账 100 DICE tokens 到测试地址
- **发送方**: 部署者地址
- **接收方**: `0x________________`
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 3. Sell 操作
- **交易哈希**: `0x________________`
- **说明**: 出售 50 DICE tokens，获得 30000 wei (0.00003 ETH)
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

---

## Stage 2 Dice 合约

- **合约地址**: `0x________________`
- **部署交易**: `0x________________`
- **Etherscan链接**: https://sepolia.etherscan.io/address/0x________________
- **关联Token合约**: `0x________________` (Stage1)

### Token 奖金池

- **充值交易**: `0x________________`
- **充值金额**: 10000 DICE tokens
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

### 游戏执行记录

#### 1. 创建游戏 (Player A)
- **交易哈希**: `0x________________`
- **Player A 地址**: `0x________________`
- **Bet Amount**: 0.01 ETH (10000000000000000 wei)
- **Fingerprint A**: `0x________________`
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 2. 加入游戏 (Player B)
- **交易哈希**: `0x________________`
- **Player B 地址**: `0x________________`
- **Bet Amount**: 0.01 ETH
- **Fingerprint B**: `0x________________`
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 3. Reveal A
- **交易哈希**: `0x________________`
- **Secret A**: `keccak256(abi.encodePacked("secretA123"))`
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 4. Reveal B
- **交易哈希**: `0x________________`
- **Secret B**: `keccak256(abi.encodePacked("secretB456"))`
- **Etherscan**: https://sepolia.etherscan.io/tx/0x________________

#### 5. 结算结果
- **随机数 n**: ____ (1-6)
- **获胜者**: `0x________________`
- **ETH 奖励**: 0.02 ETH
- **Token 奖励**: 100 DICE
- **结算事件**: DiceGameSettled(winner, profits, stage1TokenBonus)

---

## 验证清单

- [ ] Stage1 合约已部署到 Sepolia
- [ ] Stage1 Mint 交易成功
- [ ] Stage1 Transfer 交易成功
- [ ] Stage1 Sell 交易成功
- [ ] Stage2 合约已部署到 Sepolia
- [ ] Stage2 奖金池已充值
- [ ] 完整游戏流程执行成功
- [ ] 获胜者收到 ETH 奖励
- [ ] 获胜者收到 Token 奖励
- [ ] 所有交易在 Etherscan 可查

---

## 备注

- 测试网络: Sepolia
- 使用工具: Remix IDE + MetaMask
- 测试日期: ____-__-__
