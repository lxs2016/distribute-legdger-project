pragma solidity ^0.8.0;

/**
    接口：调用外部合约Stage1的发放奖励和查询余额函数
**/
interface IStage1 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Stage2{
    // 游戏状态枚举
    enum DiceGameState { None, WaitingForB, BothBetted, Settled }
    // stateMachine
    DiceGameState public diceGameState;
    // 发放token合约对象
    IStage1 public tokenContract;
    // 每场赌约的固定token数
    uint16 public constant TOKEN_BONUS = 100; 

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

    // 异常集合
    error WrongState();
    error InvalidParam();
    error NotBetOwner();
    error RepeatedRevealed();
    error BetMismatch();


    constructor(address tokenContractAddress){
        require(tokenContractAddress != address(0), "invaild tokenContractAddress");
        // 初始化时 让Stage2合约能知道Stage1的存在
        tokenContract = IStage1(tokenContractAddress);
    }

    // 第一阶段：A 下注 第一个人默认选小 1-3胜
    function createDiceGame(bytes32 _fingerPrintForA) external payable{
        // 状态机校验
        if (diceGameState != DiceGameState.None) revert WrongState();
        // A 下注价格为0
        if (msg.value == 0) revert InvalidParam();
        // A 赌的结果 简单校验
        if (_fingerPrintForA == bytes32(0)) revert InvalidParam();

        gamblerA = msg.sender;
        betAmount = msg.value;
        fingerPrintForA = _fingerPrintForA;
        revealedA = false;
        // 状态转换
        diceGameState = DiceGameState.WaitingForB;
        // 记录赌局开始
        emit DiceGameCreated(gamblerA, betAmount, fingerPrintForA);
    }

    // 第二阶段 B 下注 默认选大 4-6胜
    function joinGame(bytes32 _fingerPrintForB) external payable {
        if (diceGameState != DiceGameState.WaitingForB) revert WrongState();
        // 不准同一个人同时参与一局游戏 防止刷token
        if (msg.sender == gamblerA) revert WrongState();
        // 下注金额对等校验
        if (msg.value != betAmount) revert InvalidParam();
        // A 赌的结果 简单校验
        if (_fingerPrintForB == bytes32(0)) revert InvalidParam();
      
        gamblerB = msg.sender;
        fingerPrintForB = _fingerPrintForB;
        diceGameState = DiceGameState.BothBetted;

        // 记录B加入
        emit DiceGameJoined(gamblerB, msg.value,fingerPrintForB);
    }

    // A 投注结果
    function revealA(bytes32 _secretA) external {
        if (diceGameState != DiceGameState.BothBetted) revert WrongState();
        // 防止非本人揭示赌注
        if (msg.sender != gamblerA) revert NotBetOwner();
        // 防止重复揭示
        if (revealedA) revert RepeatedRevealed();
        // 校验赌注是否有效
        if (keccak256(abi.encodePacked(_secretA)) != fingerPrintForA) revert BetMismatch(); 
     
        secretA = _secretA;
        revealedA = true;
        // 记录事件
        emit BetForARevealed();
        // 如果此时B也已经揭示了 直接进入结算
        if (revealedB) _diceGameSettle(); 
    }


    // B 投注结果
    function revealB(bytes32 _secretB) external {
        if (diceGameState != DiceGameState.BothBetted) revert WrongState();
        // 防止非本人揭示赌注
        if (msg.sender != gamblerB) revert NotBetOwner();
        // 防止重复揭示
        if (revealedB) revert RepeatedRevealed();
        // 校验赌注是否有效
        if (keccak256(abi.encodePacked(_secretB)) != fingerPrintForB) revert BetMismatch(); 
     
        secretB = _secretB;
        revealedB = true;
        // 记录事件
        emit BetForBRevealed();
        // 如果此时B也已经揭示了 直接进入结算
        if (revealedA) _diceGameSettle(); 
    }

    // 赌局结算 
    // 随机种子：使用 A 和 B 的私钥以及区块号
    // 结果：赢的人拿走所有赌注和stage1中token奖励
    function _diceGameSettle() private {
        bytes32 randomSeed = keccak256(abi.encodePacked(secretA, secretB, block.number));
        uint256 n = (uint256(randomSeed) % 6) + 1;
        // 默认规则：1-3 A 胜，4-6 B 胜
        winner = n <= 3 ? gamblerA : gamblerB; 
        // 合约内全部赌注给winner
        uint256 profits = address(this).balance; 
        // stage1 中 额外给出奖励
        uint256 balanceOfStage1 = tokenContract.balanceOf(address(this)); 
        uint256 stage1TokenBonus = balanceOfStage1 >= TOKEN_BONUS ? TOKEN_BONUS : balanceOfStage1;

        // Checks-effects-interactions：先改状态、发事件，再对外转 ETH/代币（防重入）
        diceGameState = DiceGameState.Settled;
        emit DiceGameSettled(winner, profits, stage1TokenBonus);

        // 先 reset 再转账
        _reset(); 
        (bool sent, ) = payable(winner).call{value: profits}("");
        require(sent, "Bet profits failed to send");
        if (stage1TokenBonus > 0) {
            bool tokenSent = tokenContract.transfer(winner, stage1TokenBonus);
            require(tokenSent, "Stage1token bonus failed to send");
        }
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
        diceGameState = DiceGameState.None;
    }


    receive() external payable {}



}