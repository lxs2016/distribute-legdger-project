## 1. 阶段1：部署代币合约（文档第 4 节、视频第 7.2.2）

1. 在 Remix 里选择 `Stage1` 合约。

2. 点 Deploy。

3. 填构造函数参数（`constructor(string name, string symbol)`）：

   - `name`： `Stage1Token`
   - `symbol`： `S1`

4. 部署完成后，复制并记录：

   - `Stage1` 的合约地址（用于后面 `Stage2` 部署与校验）：0xFcCd035eDF9Cb7040D5825CE320f62AD1c7562Ea

   - 部署交易的 `tx hash`（Remix 右侧 Transaction details 里能看到）

      0x7bfc07843bad465896ca8285ab727f22868b6397d543550b5868068ba7aa69fc

   - gas ： 1222508 gas

------

## 2. 阶段1交互：演示 `mint()`（文档第 4.3、视频第 7.2.3）

> 代码约束：`mint` 仅合约所有者可调用（`require(msg.sender == owner)`）

1. 在 `Stage1` 已部署页面，选择 `mint(address to, uint256 value)`。

2. 用部署 Stage1 的同一个账号调用（即 owner）：

   - `to`： `0x7fdF3DB473AE5682222c0300A24493ba80B68aF7`
   - `value`：1000

3. 提交交易，记录该 `mint` 的 `tx hash` : 

   0xd2246b5311b0f36d1f1e68a5dfae6fd51f47bd08322ed69b06c5a5c40c00dc24

4. 在事件里应看到：

   - `Mint(to, value)` 事件。

| transaction cost | 70985 gas |
| ---------------- | --------- |



------

## 3. 阶段1交互：演示 `transfer()`（文档第 4.3、视频第 7.2.3）

1. 调用 `transfer(address to, uint256 value)`：

   - `to`：`0x6BC4baEa0A2e77b3cc9ceAADDDEb5d82fad42134`
   - `value`：500 

2. 提交交易并记录 `tx hash` : 

   0xdce3300d9bb9c12cd7ef0f824deb771ff0159feb80c83059e643f9f39ffa1f1f

3. 检查事件：

   - `Transfer(from, to, value)` 是否触发。

   | transaction cost | 52360 gas |
   | ---------------- | --------- |

------

## 4. 阶段1交互：演示 `sell()` 充值

> 代码约束：`sell` 会向调用者转 ETH，因此 `Stage1` 合约地址必须先有 ETH（靠 `receive()` 接收）。

1. 先给 `Stage1` 合约“充值 ETH”（用于 sell 支付）：

   - 在 Remix 里找到部署后的合约地址实例
   - 发起一个交易给 `Stage1` 地址，`Value` 填入，例如 `0.001 ETH` 0x22effec9e16463e9654ecbd42861777826afb78fcbdefa10d269f607695f274c

2. 再从“拥有足够代币”的账号（例如账号 A）调用：

   - `sell(uint256 value)`， `sell(100)`

3. 记录 `tx hash`。 0xd3c5509590fcc92bbb8c4a7dbc4fb0505a6866200f1beb6c53ef6066a7836cb6

4. 检查应触发事件：

   - `Sell(from, value)`。

   | transaction cost | 44280 gas |
   | ---------------- | --------- |

------

## 5. 阶段2：部署掷骰游戏合约（文档第 5 节、视频第 7.2.4）

1. 在 Remix 选择 `Stage2` 合约。

2. 部署参数：`constructor(address tokenContractAddress)`

   - 填入你刚才 `Stage1` 部署得到的合约地址

3. 部署后记录：

   - `Stage2` 合约地址 ： 0x75142ba7e66DD0c04B3b146e2f97DF963f1BbF9F

   - 部署交易 `tx hash`:  0xc6455e736177a39d70c308a78c227fee086c04a26d34283e6227afeb89e20c37

   - | transaction cost | 2301865 gas |
     | ---------------- | ----------- |

------

## 6. 阶段2必做：预充代币奖金池（文档第 5.2 强制要求）

> 代码里 `Stage2` 的奖励是从“自己地址上的 Stage1 余额”转出的： `stage1TokenBonus = min(tokenContract.balanceOf(address(this)), TOKEN_BONUS)`
>
> ```
> TOKEN_BONUS = 100
> ```

1. 用 `Stage1` 的 `mint()`（仍然只能 owner 调用）给 `Stage2` 合约地址打款代币：

   - `to`：0x75142ba7e66DD0c04B3b146e2f97DF963f1BbF9F
   - `value`: 100000

2. 记录这笔 `mint` 的 `tx hash` : 0xd3162a40254662e05b1d746826c78fa32b48d9e9e59219a82beffce16d2da3c0

   | transaction cost | 53909 gas |
   | ---------------- | --------- |

------

## 7. 一局完整掷骰游戏（文档第 5.1~5.4、视频第 7.2.5）

### 7.1 你需要先准备的参数（非常关键）

`Stage2` 使用“承诺-揭示（commit-reveal）”：

- 你要提供
  -  `secretA`： `0x0000000000000000000000000000000000000000000000000000000000000001`
  -  ``secretB`: `0x0000000000000000000000000000000000000000000000000000000000000002`
- 合约收到的是
  -  `fingerPrintForA`: `0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6`
  -  `fingerPrintForB`: `0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace`
- 校验规则在代码里是：
  - `keccak256(abi.encodePacked(_secretA)) == fingerPrintForA`
  - `keccak256(abi.encodePacked(_secretB)) == fingerPrintForB`

### 7.2 下注与加入

1. 下注（A 创建游戏）：

   - 从账号 A调用 `createDiceGame(bytes32 _fingerPrintForA)` ：0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6

   - `msg.value` 设为 `betAmount`：200 wei

   - Trx : 0x6331c4a3db2f56c18e7fb6829c56701847d4335718e3c8c8eca2db3dec1bcf5a

   - | transaction cost | 120417 gas |
     | ---------------- | ---------- |

2. 加入（B 跟注）：

   - 从账号 B调用 `joinGame(bytes32 _fingerPrintForB)` : 0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace

   - `msg.value` 必须等于 `betAmount` : 200 wei

   - Trx : 0x90f9573051dc3ef40a18e910bfca3a4f2301dc3706ff885932f22e71e50c78d2

   - | transaction cost | 100232 gas |
     | ---------------- | ---------- |

调用后应看到事件：

- `DiceGameCreated(gamblerA, betAmount, fingerPrintForA)`
- `DiceGameJoined(gamblerB, betAmount, fingerPrintForB)`

### 7.3 揭示（结算发生在第二方揭示之后）

1. 账号 A 揭示：

   - 从账号 A 调用 `revealA(bytes32 _secretA)` 切换账号

   - Trx: 0x13b3c6737ebd4dcd467116f506733ef0be5d95579306bc2ae0e94236cf783dd0

   - | transaction cost | 75817 gas |
     | ---------------- | --------- |

2. 账号 B 揭示（通常这一步会触发结算）： 切换账号

   - 从账号 B 调用 `revealB(bytes32 _secretB)`

   - Trx: 0xd0b42a6178041a4c293b614c97a1c208cb73cc351baf142d0f12b78817d6e013

   - | transaction cost | 120010 gas |
     | ---------------- | ---------- |

结算时事件：

- `DiceGameSettled(winner, profits, stage1TokenBonus)`

你在事件里能看到赢家地址与 `stage1TokenBonus`，并且应该能在 `Stage1.balanceOf(winner)`、`Stage1.balanceOf(stage2)` 上看到余额变化（或至少看到转账相关日志）。