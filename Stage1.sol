pragma solidity ^0.8.0;

contract Stage1{
    // 重入防护锁
    bool private _locked = false;
    
    // 重入防护修饰器
    modifier nonReentrant() {
        require(!_locked, 'Reentrant call');
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

    uint128 private constant PRICE_WEI_PER_TOKEN = 600;

    // contract internal state
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    // 
    mapping(address => uint256) private _balances;

    // 构造函数
    constructor(string memory name, string memory symbol) {
        owner = payable(msg.sender);
        _name = name;
        _symbol = symbol;
    }

    // view functions 
      function getName() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getSymbol() external view returns (string memory) {
        return _symbol;
    }

    function getPrice() external pure returns (uint128) {
        return PRICE_WEI_PER_TOKEN;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // State-Changing Functions
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

    function close() external {
        require(msg.sender == owner, "only owner");
        selfdestruct(owner);
    }

    // Fallback: enables anyone to send Ether to the contract account.
    receive() external payable {}
}


