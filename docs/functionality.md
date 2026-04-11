# 功能说明文档

本文档详细介绍分布式账本项目的各个功能模块和技术实现。

## 目录

1. [合约架构概述](#合约架构概述)
2. [Stage1 代币合约功能](#stage1-代币合约功能)
3. [Stage2 游戏合约功能](#stage2-游戏合约功能)
4. [安全机制](#安全机制)
5. [事件日志](#事件日志)

---

## 合约架构概述

```
┌─────────────────────────────────────────────────────────┐
│                    用户交互层                            │
│  (Web3 DApp / MetaMask / Remix)                         │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   Stage2 Game Contract                   │
│  - 骰子对战游戏逻辑                                       │
│  - 奖励发放                                              │
│  - 超时/取消处理                                         │
└─────────────────────────────────────────────────────────┘
                           │
          奖励发放 ◄──────────┴──────────► ETH/代币
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  Stage1 Token Contract                   │
│  - ERC20 代币                                           │
│  - 代币铸造                                             │
│  - 代币销售                                             │
│  - ETH 管理                                            │
└─────────────────────────────────────────────────────────┘
```

---

## Stage1 代币合约功能

### 1.1 基础信息

| 函数 | 描述 | 权限 |
|------|------|------|
| `name()` | 返回代币名称 | 公开 |
| `symbol()` | 返回代币符号 | 公开 |
| `totalSupply()` | 返回总供应量 | 公开 |
| `pricePerToken()` | 返回代币单价 (600 wei) | 公开 |

### 1.2 余额查询

```solidity
function balanceOf(address account) external view returns (uint256);
```

返回指定账户的代币余额。

### 1.3 代币授权

符合 ERC20 标准，支持以下授权操作：

| 函数 | 描述 |
|------|------|
| `approve(spender, amount)` | 授权指定地址可使用一定数量的代币 |
| `allowance(owner, spender)` | 查询授权额度 |
| `increaseAllowance(spender, addedValue)` | 增加授权额度 |
| `decreaseAllowance(spender, subtractedValue)` | 减少授权额度 |

### 1.4 代币转账

| 函数 | 描述 |
|------|------|
| `transfer(to, value)` | 从当前账户转账代币 |
| `transferFrom(from, to, amount)` | 从授权账户转账代币 |

### 1.5 代币铸造（仅所有者）

```solidity
function mint(address to, uint256 value) external returns (bool);
```

- 只能由合约所有者调用
- 创建新代币并发送到指定地址
- 自动增加总供应量
- 触发 `Mint` 事件

### 1.6 代币销售

```solidity
function sell(uint256 value) external nonReentrant returns (bool);
```

用户可以将代币出售给合约，换取ETH：

- **价格**: 600 wei / token
- **流程**:
  1. 用户授权代币给合约
  2. 调用 sell() 函数
  3. 合约扣除代币，发送ETH给用户
  4. 触发 `Sell` 事件

### 1.7 ETH 提取（仅所有者）

```solidity
function withdraw() external nonReentrant;
```

合约所有者可以提取合约中的所有ETH。

### 1.8 紧急代币提取（仅所有者）

```solidity
function emergencyWithdrawToken(address tokenAddress, uint256 amount) external nonReentrant;
```

当合约意外收到其他代币时，所有者可以提取出来。

---

## Stage2 游戏合约功能

### 2.1 游戏状态机

游戏通过状态机控制流程：

```
    ┌──────────┐
    │   None   │ ◄──── 游戏结束清空
    └────┬─────┘
         │ createDiceGame()
         ▼
┌─────────────────┐
│ WaitingForB    │ ───── 取消游戏/超时处理
└────┬────────────┘
     │ joinGame()
     ▼
┌─────────────────┐
│  BothBetted    │ ── checkTimeout() 可触发超时
└────┬────────────┘
     │ revealA() + revealB()
     ▼
┌─────────────────┐
│    Settled     │ ─── 结算完成
└────┬────────────┘
     │ _reset()
     ▼
    None
```

### 2.2 游戏创建

```solidity
function createDiceGame(bytes32 _fingerPrintForA) external payable nonReentrant;
```

**参数说明：**
- `_fingerPrintForA`: 玩家A的哈希承诺（不可为0）

**前置条件：**
- 游戏状态必须为 None
- 下注金额必须大于 0

**执行流程：**
1. 记录玩家A地址
2. 记录下注金额
3. 存储哈希承诺
4. 更新状态为 WaitingForB
5. 触发 `DiceGameCreated` 事件

### 2.3 加入游戏

```solidity
function joinGame(bytes32 _fingerPrintForB) external payable nonReentrant;
```

**参数说明：**
- `_fingerPrintForB`: 玩家B的哈希承诺

**前置条件：**
- 游戏状态必须为 WaitingForB
- 加入者不能是游戏创建者
- 下注金额必须与创建者相同

### 2.4 揭示秘密

```solidity
function revealA(bytes32 _secretA) external nonReentrant;
function revealB(bytes32 _secretB) external nonReentrant;
```

**参数说明：**
- `_secretA` / `_secretB`: 玩家之前提交的哈希承诺对应的原始秘密

**验证逻辑：**
- 使用 `keccak256(abi.encodePacked(secret))` 计算哈希
- 必须与之前提交的指纹匹配

### 2.5 结算机制

当双方都揭示秘密后，系统自动进行结算：

**随机数生成算法：**
```solidity
bytes32 randomSeed = keccak256(abi.encodePacked(
    secretA,           // 玩家A的秘密
    secretB,           // 玩家B的秘密
    block.number,      // 当前块号
    block.timestamp,   // 当前时间戳
    gamblerA,          // 玩家A地址
    gamblerB           // 玩家B地址
));
uint256 n = (uint256(randomSeed) % 6) + 1;  // 生成1-6的随机数
```

**胜负判定：**
- 1, 2, 3 点 → 玩家A获胜
- 4, 5, 6 点 → 玩家B获胜

**奖励分配：**
- 赢家获得合约内全部ETH
- 赢家获得 Stage1 代币奖励（100代币）

### 2.6 超时机制

```solidity
function checkTimeout() external nonReentrant;
function getRemainingTimeout() external view returns (uint256);
```

**超时规则：**
- 超时时限：30分钟（从B加入游戏开始计时）
- 先揭示方获胜
- 超时后可调用 `checkTimeout()` 强制结算

### 2.7 取消游戏

```solidity
function cancelGame() external nonReentrant;
function getRemainingCancelTime() external view returns (uint256);
```

**取消条件：**
- 仅有游戏创建者可以取消
- 游戏状态必须为 WaitingForB
- 必须在创建后30分钟内

---

## 安全机制

### 3.1 重入攻击防护

所有关键函数都使用了 `nonReentrant` 修饰器：

```solidity
modifier nonReentrant() {
    require(!_locked, "Reentrant call");
    _locked = true;
    _;
    _locked = false;
}
```

**保护的函数：**
- Stage1: `sell()`, `withdraw()`, `emergencyWithdrawToken()`
- Stage2: `createDiceGame()`, `joinGame()`, `revealA()`, `revealB()`, `checkTimeout()`, `cancelGame()`

### 3.2 Checks-Effects-Interactions 模式

在状态变更前执行所有检查，遵循CEI模式：

```solidity
function _diceGameSettle() private {
    // 1. 计算奖励
    uint256 profits = address(this).balance;
    uint256 stage1TokenBonus = ...;

    // 2. 状态变更（先于转账）
    diceGameState = DiceGameState.Settled;
    emit DiceGameSettled(winner, profits, stage1TokenBonus);

    // 3. 重置状态
    _reset();

    // 4. 最后才转账（防重入）
    (bool sent, ) = payable(winner).call{value: profits}("");
    require(sent, "Bet profits failed to send");
}
```

### 3.3 多熵源随机数

使用多个独立的熵源生成随机数，降低被操纵风险：

```solidity
bytes32 randomSeed = keccak256(abi.encodePacked(
    secretA,       // 玩家A的秘密
    secretB,       // 玩家B的秘密
    block.number,  // 块号
    block.timestamp, // 时间戳
    gamblerA,      // 玩家A地址
    gamblerB       // 玩家B地址
));
```

---

## 事件日志

### Stage1 事件

| 事件名称 | 参数 | 描述 |
|----------|------|------|
| `Transfer` | from, to, value | 代币转账 |
| `Mint` | to, value | 代币铸造 |
| `Sell` | from, value | 代币出售 |
| `Approval` | owner, spender, value | 授权变更 |

### Stage2 事件

| 事件名称 | 参数 | 描述 |
|----------|------|------|
| `DiceGameCreated` | gamblerA, betAmount, fingerPrintForA | 游戏创建 |
| `DiceGameJoined` | gamblerB, betAmount, fingerPrintForB | 玩家B加入 |
| `BetForARevealed` | - | 玩家A揭示 |
| `BetForBRevealed` | - | 玩家B揭示 |
| `DiceGameSettled` | winner, profits, stage1TokenBonus | 游戏结算 |

---

## 错误处理

### Stage2 自定义错误

| 错误名称 | 参数 | 描述 |
|----------|------|------|
| `WrongState` | expected, actual | 状态机错误 |
| `InvalidParam` | message | 参数无效 |
| `NotBetOwner` | caller, expected | 非游戏参与者 |
| `RepeatedRevealed` | caller | 重复揭示 |
| `BetMismatch` | expected, actual | 秘密不匹配 |

---

*文档更新时间: 2026年3月*