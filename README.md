# Distribute Ledger Project (分布式账本项目)

一个基于以太坊智能合约的去中心化骰子对战游戏系统。

## 项目简介

本项目包含两个核心智能合约：

| 合约 | 功能描述 |
|------|----------|
| **Stage1.sol** | ERC20代币合约，提供游戏用的代币经济系统 |
| **Stage2.sol** | 骰子对战游戏合约，支持双人公平对战 |

### 核心特性

- **代币系统**: 完整的ERC20标准代币，支持铸造、交易、销毁
- **公平对战**: 采用 Commit-Reveal 机制确保游戏公平性
- **安全防护**: 重入攻击防护、多熵源随机数
- **超时保护**: 30分钟超时机制，防止资金锁定

## 技术栈

- **智能合约**: Solidity ^0.8.0
- **开发工具**: Remix IDE, Hardhat
- **测试**: Foundry, Mocha/Chai

## 快速开始

### 环境要求

- Node.js >= 16.0
- npm 或 yarn
- MetaMask 钱包 (测试网络)

### 部署步骤

1. **编译合约**
   ```bash
   # 使用 Remix 或 Hardhat 编译
   npx hardhat compile
   ```

2. **部署 Stage1 合约**
   - 部署时传入代币名称和符号（如 "GameToken", "GT"）
   - 记录部署后的合约地址

3. **部署 Stage2 合约**
   - 部署时传入 Stage1 合约地址作为构造参数
   - 确保 Stage1 合约中有足够的代币用于奖励

4. **配置代币奖励**
   - 向 Stage1 合约铸造代币
   - 将代币转入 Stage2 合约作为奖励池

## 合约交互

### Stage1 代币操作

```solidity
// 铸造代币（仅所有者）
stage1.mint(to, amount);

// 查询余额
stage1.balanceOf(account);

// 授权转账
stage1.approve(spender, amount);
stage1.transferFrom(from, to, amount);

// 出售代币
stage1.sell(tokenAmount);

// 提取ETH（仅所有者）
stage1.withdraw();
```

### Stage2 游戏操作

```solidity
// 第一阶段：A 创建游戏
stage2.createDiceGame{value: betAmount}(fingerPrintForA);

// 第二阶段：B 加入游戏
stage2.joinGame{value: betAmount}(fingerPrintForB);

// A 揭示秘密
stage2.revealA(secretA);

// B 揭示秘密
stage2.revealB(secretB);

// 超时处理（可选）
stage2.checkTimeout();

// 取消游戏（仅创建者，可取消时段内）
stage2.cancelGame();
```

## 文档

- [使用文档](./docs/user-guide.md)
- [功能说明](./docs/functionality.md)
- [更新报告](./docs/update-report.md)

## 安全说明

1. 部署前请进行完整的安全审计
2. 所有者地址请妥善保管，切勿公开
3. 建议在测试网充分验证后再部署到主网

## 许可证

MIT License

---

*项目最后更新: 2026年3月*