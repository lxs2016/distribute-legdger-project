// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Stage1 Token Contract
 * @dev 这是一个简单的 ERC20 代币合约，支持代币转账、铸造和卖出功能
 * 
 * 功能特性：
 * 1. 代币转账功能 (transfer)
 * 2. 铸造新代币 (mint) - 仅合约所有者可用
 * 3. 卖出代币换取 ETH (sell) - 按固定价格 600 wei/token
 * 4. 重入攻击防护
 * 5. 合约可被所有者关闭 (close)
 */
contract Stage1 {
    // ============================
    // 重入防护机制
    // ============================
    
    /**
     * @dev 重入防护锁，防止重入攻击
     * 在关键函数执行期间锁定，阻止嵌套调用
     */
    bool private _locked = false;
    
    /**
     * @dev 重入防护修饰器
     * 使用检查-效果-交互模式 (Checks-Effects-Interactions) 防止重入攻击
     * 
     * 工作原理：
     * 1. 检查：验证锁未被持有（允许调用）
     * 2. 设置：立即锁定
     * 3. 执行：运行函数主体
     * 4. 解锁：函数返回后释放锁
     * 
     * 注意：由于 Solidity 修饰器的执行顺序，
     * 锁定在函数主体之前设置，在函数主体之后释放
     */
    modifier nonReentrant() {
        require(!_locked, 'Reentrant call');
        _locked = true;
        _;
        _locked = false;
    }

    // ============================
    // 合约状态变量
    // ============================
    
    /// @dev 合约所有者地址，可用于铸造代币和关闭合约
    address payable public owner;
    
    // ============================
    // 事件定义
    // ============================
    
    /**
     * @dev 转账事件
     * @param from 代币转出地址
     * @param to 代币转入地址
     * @param value 转账数量
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev 铸造事件（代币增发）
     * @param to 获得新代币的地址
     * @param value 铸造的代币数量
     */
    event Mint(address indexed to, uint256 value);
    
    /**
     * @dev 卖出事件（代币销毁并换 ETH）
     * @param from 卖出代币的地址
     * @param value 卖出的代币数量
     */
    event Sell(address indexed from, uint256 value);

    // ============================
    // 常量定义
    // ============================
    
    /**
     * @dev 代币价格：600 wei 每个代币
     * @notice 这是固定价格，不可更改
     */
    uint128 private constant PRICE_WEI_PER_TOKEN = 600;

    // ============================
    // 内部状态变量
    // ============================
    
    /// @dev 代币总供应量
    uint256 private _totalSupply;
    
    /// @dev 代币名称（如 "MyToken"）
    string private _name;
    
    /// @dev 代币符号（如 "MTK"）
    string private _symbol;
    
    /**
     * @dev 地址到代币余额的映射
     * @notice 使用 private 修饰符防止直接访问，通过 balanceOf 函数查询
     */
    mapping(address => uint256) private _balances;

    // ============================
    // 构造函数
    // ============================
    
    /**
     * @dev 构造函数，初始化代币合约
     * @param name 代币名称
     * @param symbol 代币符号
     * 
     * @notice 部署时设置代币名称和符号，合约创建者为所有者
     * @notice 初始代币供应量为 0，需要通过 mint 铸造
     */
    constructor(string memory name, string memory symbol) {
        owner = payable(msg.sender);  // 记录合约部署者地址
        _name = name;
        _symbol = symbol;
    }

    // ============================
    // 只读函数 (View Functions)
    // ============================
    
    /**
     * @dev 获取代币名称
     * @return 代币名称字符串
     */
    function getName() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev 获取代币总供应量
     * @return 代币总供应量
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev 获取代币符号
     * @return 代币符号字符串
     */
    function getSymbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev 获取代币价格
     * @return 每个代币的价格（单位：wei）
     * 
     * @notice 纯函数，不读取状态，可用于 gas 优化
     */
    function getPrice() external pure returns (uint128) {
        return PRICE_WEI_PER_TOKEN;
    }

    /**
     * @dev 查询指定地址的代币余额
     * @param account 要查询的地址
     * @return 该地址持有的代币数量
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // ============================
    // 状态变更函数 (State-Changing Functions)
    // ============================
    
    /**
     * @dev 转账功能 - 将代币从调用者账户转移到目标账户
     * @param to 接收代币的目标地址
     * @param value 要转账的代币数量
     * @return 是否转账成功
     * 
     * @dev 安全考虑：
     * 1. 检查目标地址不为零地址（防止发送到黑洞地址）
     * 2. 检查发送方余额充足
     * 3. 先减后加余额顺序（防止整数溢出）
     * 
     * @dev 事件说明：
     * 成功时触发 Transfer 事件，记录转账信息
     */
    function transfer(address to, uint256 value) external returns (bool) {
        // 地址有效性校验：不能转账到零地址
        require(to != address(0), "cannot transfer to 0x0");
        // 余额校验：发送方必须有足够的代币
        require(_balances[msg.sender] >= value, "no enough balance");

        // 防止 DAO 攻击：先减后加，确保余额更新原子性
        // 这样可以防止重入攻击和整数溢出问题
        _balances[msg.sender] -= value;
        _balances[to] += value;

        // 记录转账事件，供前端和监控系统监听
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 铸造新代币 - 合约所有者专用
     * @param to 接收新代币的地址
     * @param value 要铸造的代币数量
     * @return 是否铸造成功
     * 
     * @dev 安全考虑：
     * 1. 仅允许合约所有者调用（防止非法增发）
     * 2. 检查目标地址不为零（防止烧毁代币）
     * 
     * @dev 经济机制：
     * - 铸造会增加总供应量 (_totalSupply)
     * - 代币直接添加到接收者余额
     * - 触发 Mint 事件记录增发
     * 
     * @notice 这个函数需要信任合约所有者，应在部署时设置合理的所有者权限
     */
    function mint(address to, uint256 value) external returns (bool) {
        // 权限校验：仅合约所有者可以铸造
        require(msg.sender == owner, "only owner may call");
        // 地址校验：不能铸造到零地址
        require(to != address(0), "mint to zero");

        // 增加总供应量
        _totalSupply += value;
        // 增加接收者余额
        _balances[to] += value;
        // 记录铸造事件
        emit Mint(to, value);

        return true;
    }

    /**
     * @dev 卖出代币 - 将代币兑换为 ETH
     * @param value 要卖出的代币数量
     * @return 是否卖出成功
     * 
     * @dev 工作流程：
     * 1. 校验卖出数量大于 0
     * 2. 校验用户有足够代币
     * 3. 校验合约有足够 ETH
     * 4. 扣除用户代币和总供应量
     * 5. 向用户支付 ETH
     * 
     * @dev 安全考虑：
     * 1. 使用 nonReentrant 修饰器防止重入攻击
     * 2. 使用 Checks-Effects-Interactions 模式
     * 3. 先更新状态（扣除代币），再转 ETH（外部调用）
     * 
     * @dev 价格机制：
     * - 单价：600 wei / token
     * - 总价 = 单价 × 数量
     * - 例如：卖出 10 个代币可获得 6000 wei (0.006 ETH)
     * 
     * @notice 重要：合约必须有足够的 ETH 储备才能成功卖出
     */
    function sell(uint256 value) external nonReentrant returns (bool) {
        // 数量校验：不能卖出 0 或负数
        require(value > 0, "cannot sell zero or below");
        // 余额校验：用户必须有足够的代币
        require(_balances[msg.sender] >= value, "no enough balance");

        // 计算应该支付给用户的 ETH 数量
        // 使用 uint256 确保乘法运算不溢出
        uint256 weiRequired = uint256(PRICE_WEI_PER_TOKEN) * value;
        
        // 合约余额校验：确保合约有足够 ETH 支付用户
        // 这是必要的，因为合约可能没有足够的 ETH 储备
        require(address(this).balance >= weiRequired, "contract insufficient ETH");

        // _checks-Effects-Interactions_：先更新状态，再进行外部调用
        
        // 扣除用户代币
        _balances[msg.sender] -= value;
        // 减少总供应量（代币被"烧毁"）
        _totalSupply -= value;

        // 记录卖出事件
        emit Sell(msg.sender, value);

        // 向用户支付 ETH
        // 使用 call 而不是 transfer，避免 gas 限制问题
        (bool sent, ) = payable(msg.sender).call{value: weiRequired}("");
        require(sent, "ETH transfer failed");
        return true;
    }

    /**
     * @dev 关闭合约 - 合约所有者专用
     * 
     * @dev 功能：
     * 1. 验证调用者是合约所有者
     * 2. 销毁合约，将合约剩余 ETH 转给所有者
     * 
     * @dev 安全考虑：
     * - 仅所有者可调用
     * - selfdestruct 是不可逆操作
     * 
     * @notice 谨慎使用，确保所有业务逻辑已完成后再调用
     */
    function close() external {
        // 权限校验：仅合约所有者
        require(msg.sender == owner, "only owner");
        // 销毁合约，将余额转给所有者
        selfdestruct(owner);
    }

    /**
     * @dev 接收 ETH 的回调函数
     * 
     * @dev 用途：
     * - 允许任何人向合约充值 ETH
     * - 这是卖出功能所必需的（需要 ETH 储备）
     * 
     * @notice 合约需要 ETH 储备才能支持卖出功能
     * @notice 如果不需要充值功能，可以移除此函数
     */
    receive() external payable {}
}
