pragma solidity ^0.8.0;

contract Stage1{
    // 重入防护锁
    bool private _locked = false;
    
    // 重入防护修饰器
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
    
    // state 
    address payable public owner;
    
    // events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Sell(address indexed from, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint128 private constant PRICE_WEI_PER_TOKEN = 600;

    // contract internal state
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    // 
    mapping(address => uint256) private _balances;
    // ERC20授权映射
    mapping(address => mapping(address => uint256)) private _allowances;

    // 构造函数
    constructor(string memory name, string memory symbol) {
        owner = payable(msg.sender);
        _name = name;
        _symbol = symbol;
    }

    // view functions 
      function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function pricePerToken() external pure returns (uint128) {
        return PRICE_WEI_PER_TOKEN;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    // ERC20标准：查询授权额度
    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    // State-Changing Functions
    // ERC20标准：授权spender可以花费msg.sender的代币
    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "approve to zero address");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    // –  Transfers value tokens from msg.sender to to.
    // –  On success: emit Transfer(from,to,value) and return true
    function transfer(address to, uint256 value) external returns (bool) {
        // 地址简单校验
        require(to != address(0), "cannot transfer to 0x0");
        // 钱包余额校验
        require(_balances[msg.sender] >= value, "no enough balance");

        // 防DAO
        _balances[msg.sender] -= value;
        _balances[to] += value;

        // 记录转账事件
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    // ERC20标准：从from地址转账到to地址（需要授权）
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(from != address(0), "transfer from zero address");
        require(to != address(0), "transfer to zero address");
        
        // 检查授权额度
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "transfer amount exceeds allowance");
        
        // 检查余额
        require(_balances[from] >= amount, "transfer amount exceeds balance");
        
        // 更新授权额度（防重入）
        _allowances[from][msg.sender] = currentAllowance - amount;
        
        // 更新余额（防重入）
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    // ERC20标准：增加授权额度
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        require(spender != address(0), "approve to zero address");
        _allowances[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }
    
    // ERC20标准：减少授权额度
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        require(spender != address(0), "approve to zero address");
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "decreased allowance below zero");
        _allowances[msg.sender][spender] = currentAllowance - subtractedValue;
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }

    // –  Only owner may call.
    // –  Creates value new tokens and assigns them to to.
    // –  On success: emit Mint(to,value) and return true.
    function mint(address to, uint256 value) external returns (bool) {
        require(msg.sender == owner, "only owner may call");
        require(to != address(0), "mint to zero");

        _totalSupply += value;
        _balances[to] += value;
        emit Mint(to, value);

        return true;
    }

    // –  Enables a user to sell tokens for wei at a price of 600 wei per token.
    // –  Sold tokens are removed from circulating supply.
    // –  On success: emit Sell(from,value) and return true        
    function sell(uint256 value) external nonReentrant returns (bool) {
        require(value > 0, "cannot sell zero or below");
        require(_balances[msg.sender] >= value, "no enough balance");

        // 计算应该支付给用户的 ETH 数量
        uint256 weiRequired = uint256(PRICE_WEI_PER_TOKEN) * value;
        // 检查合约是否有足够的 ETH 来支付用户
        require(address(this).balance >= weiRequired, "contract insufficient ETH");

        // 防重入
        _balances[msg.sender] -= value;
        _totalSupply -= value;

        emit Sell(msg.sender, value);

        (bool sent, ) = payable(msg.sender).call{value: weiRequired}("");
        require(sent, "ETH transfer failed");
        return true;
    }

    // 提取合约中的ETH（仅所有者）
    function withdraw() external nonReentrant {
        require(msg.sender == owner, "only owner may call");
        uint256 balance = address(this).balance;
        require(balance > 0, "no ETH to withdraw");
        
        (bool sent, ) = payable(owner).call{value: balance}("");
        require(sent, "ETH transfer failed");
    }
    
    // 紧急提取代币（仅所有者）
    // 用于提取合约中可能存在的其他代币
    function emergencyWithdrawToken(address tokenAddress, uint256 amount) external nonReentrant {
        require(msg.sender == owner, "only owner may call");
        require(tokenAddress != address(0), "invalid token address");
        require(amount > 0, "amount must be greater than 0");
        
        // 调用代币合约的transfer函数
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSignature("transfer(address,uint256)", owner, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "token transfer failed");
    }

    // Fallback: enables anyone to send Ether to the contract account.
    receive() external payable {}
}


