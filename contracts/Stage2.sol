pragma solidity ^0.8.0;

/**
    接口：调用外部合约Stage1的发放奖励和查询余额函数
**/
interface IStage1 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Stage2{
    // 重入防护锁
    bool private _locked = false;
    
    // 重入防护修饰器
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
    
    // 游戏状态枚举
    enum DiceGameState { None, WaitingForB, BothBetted, Settled }
    // stateMachine
    DiceGameState public diceGameState;
    // 发放token合约对象
    IStage1 public tokenContract;
    // 每场赌约的固定token数
    uint16 public constant TOKEN_BONUS = 100; 
    // 超时时间（秒）：30分钟
    uint256 public constant TIMEOUT_DURATION = 30 * 60;

    // 事件
    event DiceGameCreated(address gamblerA, uint256 betAmount, bytes32 fingerPrintForA);
    event DiceGameJoined(address  gamblerB, uint256 betAmount, bytes32 fingerPrintForB);
    event BetForARevealed();
    event BetForBRevealed();
    event DiceGameSettled(address winner, uint256 profits, uint256 stage1TokenBonus);

    // A
    address public gamblerA;
    // A下注结果hash值
    bytes32 public fingerPrintForA;
    bytes32 public secretA;
    bool public revealedA;


    uint256 public betAmount;

    // B
    address public gamblerB;
    // B下注结果hash值
    bytes32 public fingerPrintForB;
    bytes32 public secretB;
    bool public revealedB;

    // winner
    address public winner;
    
    // 游戏时间戳
    uint256 public gameCreatedAt;
    uint256 public gameJoinedAt;

    // 异常集合
    error WrongState(DiceGameState expected, DiceGameState actual);
    error InvalidParam(string message);
    error NotBetOwner(address caller, address expected);
    error DuplicateParticipant(address caller);
    error RepeatedRevealed(address caller);
    error BetMismatch(bytes32 expected, bytes32 actual);


    constructor(address tokenContractAddress){
        require(tokenContractAddress != address(0), "invaild tokenContractAddress");
        // 初始化时 让Stage2合约能知道Stage1的存在
        tokenContract = IStage1(tokenContractAddress);
    }

    // 第一阶段：A 下注 第一个人默认选小 1-3胜
    function createDiceGame(bytes32 _fingerPrintForA) external payable nonReentrant{
        // 状态机校验
        if (diceGameState != DiceGameState.None) revert WrongState(DiceGameState.None, diceGameState);
        // A 下注价格为0
        if (msg.value == 0) revert InvalidParam("bet amount must be greater than 0");
        // A 赌的结果 简单校验
        if (_fingerPrintForA == bytes32(0)) revert InvalidParam("fingerprint cannot be zero");

        gamblerA = msg.sender;
        betAmount = msg.value;
        fingerPrintForA = _fingerPrintForA; // A 的猜测哈希值
        revealedA = false;
        // 记录游戏创建时间
        gameCreatedAt = block.timestamp;
        // 状态转换
        diceGameState = DiceGameState.WaitingForB;
        // 记录赌局开始
        emit DiceGameCreated(gamblerA, betAmount, fingerPrintForA);
    }

    // 第二阶段 B 下注 默认选大 4-6胜
    function joinGame(bytes32 _fingerPrintForB) external payable nonReentrant {
        if (diceGameState != DiceGameState.WaitingForB) revert WrongState(DiceGameState.WaitingForB, diceGameState);
        // 不准同一个人同时参与一局游戏 防止刷token
        if (msg.sender == gamblerA) revert DuplicateParticipant(msg.sender);
        // 下注金额对等校验
        if (msg.value != betAmount) revert InvalidParam("bet amount must match game bet amount");
        // A 赌的结果 简单校验
        if (_fingerPrintForB == bytes32(0)) revert InvalidParam("fingerprint cannot be zero");
      
        gamblerB = msg.sender;
        fingerPrintForB = _fingerPrintForB;
        // 记录游戏加入时间
        gameJoinedAt = block.timestamp;
        diceGameState = DiceGameState.BothBetted;

        // 记录B加入
        emit DiceGameJoined(gamblerB, msg.value,fingerPrintForB);
    }

    // A 投注结果
    function revealA(bytes32 _secretA) external nonReentrant {
        if (diceGameState != DiceGameState.BothBetted) revert WrongState(DiceGameState.BothBetted, diceGameState);
        // 防止非本人揭示赌注
        if (msg.sender != gamblerA) revert NotBetOwner(msg.sender, gamblerA);
        // 防止重复揭示
        if (revealedA) revert RepeatedRevealed(msg.sender);
        // 校验赌注是否有效
        // 验证：哈希(_secretA) == 之前存储的 fingerPrintForA
        if (keccak256(abi.encodePacked(_secretA)) != fingerPrintForA) revert BetMismatch(fingerPrintForA, keccak256(abi.encodePacked(_secretA))); 
     
        secretA = _secretA;
        revealedA = true;
        // 记录事件
        emit BetForARevealed();
        // 如果此时B也已经揭示了 直接进入结算
        if (revealedB) _diceGameSettle(); 
    }


    // B 投注结果
    function revealB(bytes32 _secretB) external nonReentrant {
        if (diceGameState != DiceGameState.BothBetted) revert WrongState(DiceGameState.BothBetted, diceGameState);
        // 防止非本人揭示赌注
        if (msg.sender != gamblerB) revert NotBetOwner(msg.sender, gamblerB);
        // 防止重复揭示
        if (revealedB) revert RepeatedRevealed(msg.sender);
        // 校验赌注是否有效
        if (keccak256(abi.encodePacked(_secretB)) != fingerPrintForB) revert BetMismatch(fingerPrintForB, keccak256(abi.encodePacked(_secretB))); 
     
        secretB = _secretB;
        revealedB = true;
        // 记录事件
        emit BetForBRevealed();
        // 如果此时B也已经揭示了 直接进入结算
        if (revealedA) _diceGameSettle(); 
    }

    // 赌局结算 
    // 随机种子：使用 A 和 B 的私钥、区块号、时间戳和参与者地址
    // 结果：赢的人拿走所有赌注和stage1中token奖励
    function _diceGameSettle() private {
        // 使用多个熵源生成更安全的随机数
        // 包括：双方秘密、区块号、区块时间戳、参与者地址
        bytes32 randomSeed = keccak256(abi.encodePacked(
            secretA, 
            secretB, 
            block.number, 
            block.timestamp,
            gamblerA,
            gamblerB
        ));
        // 骰子结果：1-6
        uint256 n = (uint256(randomSeed) % 6) + 1;
        // 默认规则：1-3 A 胜，4-6 B 胜
        winner = n <= 3 ? gamblerA : gamblerB; 
        // 合约内全部赌注给winner
        uint256 profits = address(this).balance; 
        // stage1 中 额外给出奖励
        uint256 balanceOfStage1 = tokenContract.balanceOf(address(this)); 
        uint256 stage1TokenBonus = balanceOfStage1 >= TOKEN_BONUS ? TOKEN_BONUS : balanceOfStage1;

        // Checks-effects-interactions：先改状态、发事件，再对外转 ETH/代币（防重入）
        // 注意：必须在外部转账之后再 _reset()，否则 winner 会被清空（变成 address(0)）
        address localWinner = winner;
        uint256 localProfits = profits;
        uint256 localTokenBonus = stage1TokenBonus;
        diceGameState = DiceGameState.Settled;
        emit DiceGameSettled(localWinner, localProfits, localTokenBonus);

        // 先对外转账，再清空状态（确保资金发给正确 winner）
        (bool sent, ) = payable(localWinner).call{value: localProfits}("");
        require(sent, "Bet profits failed to send");
        if (localTokenBonus > 0) {
            bool tokenSent = tokenContract.transfer(localWinner, localTokenBonus);
            require(tokenSent, "Stage1token bonus failed to send");
        }

        _reset();
    }


    // 清空赌局数据，可开下一局
    function _reset() private {
        gamblerA = address(0);
        gamblerB = address(0);
        betAmount = 0;
        fingerPrintForA = bytes32(0);
        fingerPrintForB = bytes32(0);
        secretA = bytes32(0);
        secretB = bytes32(0);
        revealedA = false;
        revealedB = false;
        winner = address(0);
        gameCreatedAt = 0;
        gameJoinedAt = 0;
        diceGameState = DiceGameState.None;
    }


    receive() external payable {}


    // 超时检查函数
    // 如果游戏超时，允许一方强制获胜
    function checkTimeout() external nonReentrant {
        // 只有在BothBetted状态下才能检查超时
        if (diceGameState != DiceGameState.BothBetted) revert WrongState(DiceGameState.BothBetted, diceGameState);
        
        // 检查是否超时
        if (block.timestamp <= gameJoinedAt + TIMEOUT_DURATION) revert InvalidParam("game has not timed out yet");
        
        // 超时处理：先揭示的一方获胜
        // 如果A已揭示而B未揭示，A获胜
        if (revealedA && !revealedB) {
            winner = gamblerA;
        } 
        // 如果B已揭示而A未揭示，B获胜
        else if (revealedB && !revealedA) {
            winner = gamblerB;
        }
        // 如果都未揭示或都已揭示（应该已结算），则不做处理
        else {
            revert InvalidParam("invalid timeout state: both revealed or none revealed");
        }
        
        // 合约内全部赌注给winner
        uint256 profits = address(this).balance; 
        // stage1 中 额外给出奖励
        uint256 balanceOfStage1 = tokenContract.balanceOf(address(this)); 
        uint256 stage1TokenBonus = balanceOfStage1 >= TOKEN_BONUS ? TOKEN_BONUS : balanceOfStage1;

        // Checks-effects-interactions：先改状态、发事件，再对外转 ETH/代币（防重入）
        // 注意：必须在外部转账之后再 _reset()，否则 winner 会被清空（变成 address(0)）
        address localWinner = winner;
        uint256 localProfits = profits;
        uint256 localTokenBonus = stage1TokenBonus;
        diceGameState = DiceGameState.Settled;
        emit DiceGameSettled(localWinner, localProfits, localTokenBonus);

        // 先对外转账，再清空状态（确保资金发给正确 winner）
        (bool sent, ) = payable(localWinner).call{value: localProfits}("");
        require(sent, "Bet profits failed to send");
        if (localTokenBonus > 0) {
            bool tokenSent = tokenContract.transfer(localWinner, localTokenBonus);
            require(tokenSent, "Stage1token bonus failed to send");
        }

        _reset();
    }
    
    // 查询剩余超时时间（秒）
    function getRemainingTimeout() external view returns (uint256) {
        if (diceGameState != DiceGameState.BothBetted) return 0;
        if (block.timestamp > gameJoinedAt + TIMEOUT_DURATION) return 0;
        return gameJoinedAt + TIMEOUT_DURATION - block.timestamp;
    }
    
    // 取消游戏功能
    // 只有在WaitingForB状态下，创建者可以取消游戏
    function cancelGame() external nonReentrant {
        // 只有在WaitingForB状态下才能取消
        if (diceGameState != DiceGameState.WaitingForB) revert WrongState(DiceGameState.WaitingForB, diceGameState);
        // 只有游戏创建者可以取消
        if (msg.sender != gamblerA) revert NotBetOwner(msg.sender, gamblerA);
        // 检查是否超时（创建后30分钟内可取消）
        if (block.timestamp > gameCreatedAt + TIMEOUT_DURATION) revert InvalidParam("cancel period has expired");
        
        // 退还赌注给创建者
        uint256 refundAmount = betAmount;
        // 重置游戏状态
        _reset();
        
        // 退还ETH
        (bool sent, ) = payable(msg.sender).call{value: refundAmount}("");
        require(sent, "Refund failed");
    }
    
    // 查询游戏创建后剩余取消时间（秒）
    function getRemainingCancelTime() external view returns (uint256) {
        if (diceGameState != DiceGameState.WaitingForB) return 0;
        if (block.timestamp > gameCreatedAt + TIMEOUT_DURATION) return 0;
        return gameCreatedAt + TIMEOUT_DURATION - block.timestamp;
    }

}