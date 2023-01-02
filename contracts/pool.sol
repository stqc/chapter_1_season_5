//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;


import "./poolMethods.sol";
import "./safemath.sol";
import "./bep20.sol";
import "./betterFactoryInterface.sol";


contract pool is poolMethods{
    using SafeMath for uint256;

    struct OHLC{
        uint256 time;
        uint256 Open;
        uint256 Low;
        uint256 High;
        uint256 Close;
    }

    address public beneficiery;
    uint256 public tokenInPool;
    uint256 public USDinPool;
    uint256 public buyTax;
    uint256 public saleTax;
    uint256 public autoLP;
    uint256 public totalBuyTax;
    uint256 public totalSaleTax;
    uint256 public DAOThreshold;
    address public admin;
    address public presaleRouter;
    address public tokenAddress;
    address public BUSDAddress;
    address public factory;
    address public referee;
    bool public LPenb;
    bool public priceSet=false;
    bool public tradingEnabled=true;
    uint256 platformFee;
    uint256 PlatformfeeOnNoTax;
    uint256 refFee;
    bool lock;
    
    bool isActive =false;
    uint256 creationTime;
    factoryMethod immutable fact;
    OHLC m;
    OHLC [] _1MinData;
    OHLC [] _1HourData;
    OHLC [] _1DayData;

    //DAO variables
    uint256 public yesVotes=0;
    uint256 public noVotes=0;
    mapping (address => uint256) private _balances;
    mapping (address=>uint256) public invested;
    mapping (address=>bool) public voted;
    uint256 private _totalSupply;
    uint8 public _decimals=0;
    string public _symbol ;
    string public _name;

    event tokenTraded();

    modifier protecc{
        require(!lock,"Transaction in progress:Reentrant call");
        lock = true;
        _;
        lock =false;
    
  }

    constructor(address token, address beneficieryA,uint256 buy, uint256 sale, uint256 LP,uint256 DAOthresh,address usd,address factoryAdd, address admin_,address ref){
        setName(IBEP20(token).symbol());
        tokenAddress =token;
        beneficiery = beneficieryA;
        referee=ref;
        factory = factoryAdd;
        buyTax =buy;
        saleTax =sale;
        autoLP=LP;
        DAOThreshold=DAOthresh;
        BUSDAddress =usd;
        fact = factoryMethod(factory);
        admin = admin_;
        m.Close=0;
        m.High=0;
        m.Low=0;
        m.Open=0;
        m.time=0;
        _1DayData.push(m);
        _1HourData.push(m);
        _1MinData.push(m);
        totalBuyTax=buyTax.add(autoLP);
        totalSaleTax=saleTax.add(autoLP);
        creationTime=block.timestamp;
        _mint(beneficiery,1);
        require(totalBuyTax<=30 && totalSaleTax<=30,"total tax cannot exceed 30%");
    }

    modifier onlyAdminAndProjectOwner{
        require(msg.sender==beneficiery || msg.sender==admin,"You are not the project owner or admin");
        _;
    }

     modifier onlyProjectOwner{
        require(msg.sender==beneficiery ,"You are not the project owner");
        _;
    }

    modifier onlyAdmin{
        require(msg.sender==admin ,"You are not the admin");
        _;
    }

   //DAO Methods
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setName(string memory sym) internal{
        bytes memory name__=abi.encodePacked(sym,"-BetterSwapDAO");
        bytes memory sym__ = abi.encodePacked(sym,"-BSLPDAO");
        _name=string(name__);
        _symbol=string(sym__);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
    function symbol() external view returns (string memory) {
        return _symbol;
    }
    function name() external view returns (string memory) {
    return _name;
    }
    function totalSupply() external view returns (uint256) {
    return _totalSupply;
    }
    function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
    }
    function _mint(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: mint to the zero address");

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
    }
    //DAO methods end

    function showTradeData(uint256 time) external view returns( OHLC [] memory){
        if(time==1){
            OHLC [] memory data = new OHLC[](_1MinData.length);
            for(uint256 i=0; i<_1MinData.length;i++){
                data[i]=_1MinData[i];
            }
            return data;
        }
        if(time==60){
            OHLC [] memory data = new OHLC[](_1HourData.length);
            for(uint256 i=0; i<_1HourData.length;i++){
                data[i]=_1HourData[i];
            }
            return data;
        }
        if(time==24){
            OHLC [] memory data = new OHLC[](_1DayData.length);
            for(uint256 i=0; i<_1DayData.length;i++){
                data[i]=_1DayData[i];
            }
            return data;
        }

    }
    function showTokenAddress() external view override returns(address){
        return tokenAddress;
    }//show the address of the token of the pool

    function showPoolBalance() external view override returns(uint256,uint256){
        return(tokenInPool,USDinPool);
    } //show the balance of BUSD-Token pair

    function tokenPerUSD() public view override returns(uint256){
        return ((tokenInPool.mul(10**18)).div(USDinPool));
    }

    function USDPerToken() public view override returns(uint256){
         return ((USDinPool.mul(10**18)).div(tokenInPool));
    }
    
    function updatePoolTax(uint256 buytx,uint256 selltx,uint256 lptx) external onlyProjectOwner{
        autoLP=lptx;
        totalBuyTax=buytx.add(autoLP);
        totalSaleTax =selltx.add(autoLP);
        require(totalBuyTax<=30 && totalSaleTax <=30,"Total tax cannot exceed 30%");
    }

    function skim() internal{
        uint256 USDBalance = IBEP20(BUSDAddress).balanceOf(address(this));
        if(USDBalance>USDinPool){
            uint256 remainder = USDBalance-USDinPool;
            IBEP20(BUSDAddress).transfer(admin, remainder);
        }
        uint256 TokenBalance = IBEP20(tokenAddress).balanceOf(address(this));
        if(TokenBalance>tokenInPool){
            uint256 remainder = TokenBalance-tokenInPool;
            IBEP20(tokenAddress).transfer(admin, remainder);
        }
    }
    function update1mChart(uint256 time, uint256 USDPricee) internal{
        uint256 len = _1MinData.length-1;
        OHLC memory current =  _1MinData[len];
        if(time-current.time>1 minutes){
            current.time = time;
            current.Open = USDPricee;
            current.Close = USDPricee;
            current.Low = USDPricee;
            current.High = USDPricee;
            _1MinData.push(current);
        }else{
            _1MinData[len].Close=USDPricee;
            _1MinData[len].Low>USDPricee?_1MinData[len].Low=USDPricee:_1MinData[len].Low=_1MinData[len].Low;
            _1MinData[len].High<USDPricee?_1MinData[len].High=USDPricee:_1MinData[len].High=_1MinData[len].High;
        }
    }

    function update1hChart(uint256 time, uint256 USDPricee) internal { 
         uint256 len = _1HourData.length-1;
        OHLC memory current =  _1HourData[len];
        if(time-current.time>1 hours){
            current.time = time;
            current.Open = USDPricee;
            current.Close = USDPricee;
            current.Low = USDPricee;
            current.High = USDPricee;
            _1HourData.push(current);
        }else{
            _1HourData[len].Close=USDPricee;
            _1HourData[len].Low>USDPricee?_1HourData[len].Low=USDPricee:_1HourData[len].Low=_1HourData[len].Low;
            _1HourData[len].High<USDPricee?_1HourData[len].High=USDPricee:_1HourData[len].High=_1HourData[len].High;
        }

    }

    function update1dChart(uint256 time, uint256 USDPricee) internal {

         uint256 len = _1DayData.length-1;
        OHLC memory current =  _1DayData[len];
        if(time-current.time>1 days){
            current.time = time;
            current.Open = USDPricee;
            current.Close = USDPricee;
            current.Low = USDPricee;
            current.High = USDPricee;
            _1DayData.push(current);
        }else{
            _1DayData[len].Close=USDPricee;
            _1DayData[len].Low>USDPricee?_1DayData[len].Low=USDPricee:_1DayData[len].Low=_1DayData[len].Low;
            _1DayData[len].High<USDPricee?_1DayData[len].High=USDPricee:_1DayData[len].High=_1DayData[len].High;
        }
    }
    
    function buyToken(uint256 amount) external override protecc{
        require(amount.mul(tokenPerUSD()).div(10**18)<(tokenInPool.mul(85)).div(100),"It seems there is insufficient liquidity");
        require(tradingEnabled,"Trading disabled for this pool by owner");
        IBEP20 token = IBEP20(tokenAddress);
        IBEP20 BUSD = IBEP20(BUSDAddress);
        
        skim();
        uint256 amountT=amount;
        require(tokenInPool==token.balanceOf(address(this)) && USDinPool==BUSD.balanceOf(address(this)),"The pool has been tampered with and needs to be fixed inorder to be usable again please ask the project owner to add the exact amount of tokens back");

        (platformFee,PlatformfeeOnNoTax,refFee) = fact.showFees();
        uint256 finalTokensGiven;
        uint256 TokenPerUSD = tokenPerUSD();
        
        uint256 taxFromTheBuy=0;

        uint256 LPtax=0;

        uint256 totalTax=0;

        uint256 platformTax=0;

         if(totalBuyTax==0){
            platformTax = (amountT.mul(PlatformfeeOnNoTax)).div(1000);
            amount=amount.sub(platformTax);
        }else{
            taxFromTheBuy = (amountT.mul(buyTax)).div(100);

            amount = amount.sub(taxFromTheBuy);

            LPtax = (amountT.mul(autoLP)).div(100);

            amount = amount.sub(LPtax);

            totalTax = LPtax.add(taxFromTheBuy);

            platformTax = (totalTax.mul(platformFee)).div(100);

            taxFromTheBuy = taxFromTheBuy.sub(platformTax);
        }
        

        {uint256 potentialPoolBalanceUSD = BUSD.balanceOf(address(this)).add(amount);
        
        uint256 potentialTokensGiven = amount.mul(TokenPerUSD);

        uint256 potentialPoolBalanceToken = token.balanceOf(address(this)).sub(potentialTokensGiven.div(10**18));

        uint256 priceAdjustedTokensPerUSD = (potentialPoolBalanceToken.mul(10**18)).div(potentialPoolBalanceUSD);

        finalTokensGiven=amount.mul(priceAdjustedTokensPerUSD);}
        
        
       
        BUSD.transferFrom(msg.sender,address(this),amount);
        BUSD.transferFrom(msg.sender,beneficiery,taxFromTheBuy);
        if(block.timestamp.sub(creationTime)< 30 days && referee!=address(0)){
            uint256 refReward = (platformTax.mul(refFee)).div(100);
            platformTax=platformTax.sub(refReward);
            BUSD.transferFrom(msg.sender, referee, refReward);
        }
        BUSD.transferFrom(msg.sender, admin, platformTax);
        BUSD.transferFrom(msg.sender, address(this), LPtax);
        USDinPool=BUSD.balanceOf(address(this));

        token.transfer(msg.sender,finalTokensGiven.div(10**18));
 

        USDinPool=BUSD.balanceOf(address(this));
        tokenInPool = token.balanceOf(address(this));

        update1dChart(block.timestamp,USDPerToken());
        update1hChart(block.timestamp, USDPerToken());
        update1mChart(block.timestamp, USDPerToken());
        
        invested[msg.sender]=(invested[msg.sender].add(finalTokensGiven)).div(10**18);

        if(finalTokensGiven>=DAOThreshold && _balances[msg.sender]<1){
            _mint(msg.sender, 1);
        }
        emit tokenTraded();
    } //buy the token from the said pool

    function sellToken(uint256 amount) override external protecc {
        require(amount.mul(USDPerToken()).div(10**18)<(USDinPool.mul(85)).div(100),"It seems there is insufficient liquidity");
        require(tradingEnabled,"Trading disabled for this pool by owner");
        IBEP20 token = IBEP20(tokenAddress);
        IBEP20 BUSD = IBEP20(BUSDAddress);
        
        skim();
        uint256 amountT=amount;

        require(tokenInPool==token.balanceOf(address(this)) && USDinPool==BUSD.balanceOf(address(this)),"The pool has been tampered with and needs to be fixed inorder to be usable again please ask the project owner to add the exact amount of tokens back");
        
        invested[msg.sender]=invested[msg.sender].sub(amount);
        token.transferFrom(msg.sender,address(this),amount);
        tokenInPool = token.balanceOf(address(this));

        uint256 finalUSDToGive;
        (platformFee,PlatformfeeOnNoTax,refFee) = fact.showFees();
        
        uint256 USDperToken = USDPerToken();

        uint256 taxFromTheSell = 0;

        uint256 LPtax = 0;

        uint256 totalTax = 0;

        uint256 platformTax =0;

        if(totalSaleTax==0){
            platformTax = (amountT.mul(PlatformfeeOnNoTax)).div(1000);
            amount=amount.sub(platformTax);
        }else{
            taxFromTheSell = (amountT.mul(saleTax)).div(100);
            amount = amount.sub(taxFromTheSell);
            LPtax = (amountT.mul(autoLP)).div(100);
            amount = amount.sub(LPtax);
            totalTax = LPtax.add(taxFromTheSell);
            platformTax = (totalTax.mul(platformFee)).div(100);
            taxFromTheSell = taxFromTheSell.sub(platformTax);
        }

        {uint256 potentialUSDToGive = (amount.mul(USDperToken));

        uint256 potentialPoolBalanceUSD = BUSD.balanceOf(address(this)).sub(potentialUSDToGive.div(10**18));

        uint256 priceAdjustedUSDperToken = (potentialPoolBalanceUSD.mul(10**18)).div(token.balanceOf(address(this)));

        finalUSDToGive = (amount.mul(priceAdjustedUSDperToken));    }

        BUSD.transfer(beneficiery,(taxFromTheSell.mul(USDperToken)).div(10**18));
        
        if(block.timestamp.sub(creationTime)< 30 days && referee!=address(0)){
            uint256 refReward = (platformTax.mul(refFee)).div(100);
            platformTax=platformTax.sub(refReward);
            BUSD.transfer(referee, (refReward.mul(USDperToken)).div(10**18));
        }

        BUSD.transfer(admin,(platformTax.mul(USDperToken)).div(10**18));
       
        BUSD.transfer(msg.sender,finalUSDToGive.div(10**18));

        token.transfer(address(this), LPtax);

        USDinPool=BUSD.balanceOf(address(this));
        tokenInPool = token.balanceOf(address(this));

        update1dChart(block.timestamp,USDPerToken());
        update1hChart(block.timestamp, USDPerToken());
        update1mChart(block.timestamp, USDPerToken());
        
        if(invested[msg.sender]<DAOThreshold){
            _burn(msg.sender,1);
        }

        emit tokenTraded();
    } //sell the token back to said pool

    function addLiquidity(uint256 tokenAmount, uint256 USDAmount) external onlyProjectOwner {
        
        if(priceSet){
            
            uint256 tokensRequired = USDAmount.mul(tokenPerUSD());
            
            // require(tokenAmount==tokensRequired.div(10**18),"Token to USD ratio missmatch");

            tokenAmount = tokensRequired.div(10**18);
        }

         IBEP20 token = IBEP20(tokenAddress);
         IBEP20 BUSD = IBEP20(BUSDAddress);

        token.transferFrom(msg.sender,address(this),tokenAmount);
        tokenInPool=token.balanceOf(address(this));

        BUSD.transferFrom(msg.sender,address(this),USDAmount);
        USDinPool = BUSD.balanceOf(address(this));
        
        if(!priceSet){
            priceSet=true;
        }


    }

    function viewBuyTax() external view override returns (uint256){
        return buyTax;
    } //view the buy tax

    function viewSellTax() external view override returns (uint256){
        return saleTax;
    }//view the sell tax

    function beneficieryAddress(address) external view override returns(address){
        return beneficiery;
    }

    function changeBeneficieryAddress(address ben) override external onlyAdmin{
        _burn(beneficiery,1);
        beneficiery=ben;
        if(_balances[beneficiery]<1){
            _mint(beneficiery,1);
        }
    }
    function requestLPRemovalDAO() external onlyProjectOwner{
        tradingEnabled=false;
    }
    
    function vote(uint256 vote) external{
        require(_balances[msg.sender]==1,"You do not have voting rights");
        require(!voted[msg.sender],"You have already voted");
        require(vote==0||vote==1,"invald value");
        require(!tradingEnabled,"voting not active");
        voted[msg.sender]=true;
        if(vote==0){
            yesVotes=yesVotes.add(1);
        }else{
            noVotes=noVotes.add(1);
        }
    }
    
    function removeLP() external onlyProjectOwner{
        require(yesVotes>=(uint256(_totalSupply).div(2)).add(1));
        IBEP20 tokenA = IBEP20(tokenAddress);
        IBEP20 BUSD = IBEP20(BUSDAddress);
        uint256 tokenABalance = tokenA.balanceOf(address(this));
        uint256 usdBalance = BUSD.balanceOf(address(this));
        tokenA.transfer(beneficiery,tokenABalance);
        BUSD.transfer(beneficiery,usdBalance);
    }

    function approveEmergencyWithdraw() external override onlyAdmin  {
           
            IBEP20 tokenA = IBEP20(tokenAddress);
            IBEP20 BUSD = IBEP20(BUSDAddress);
            uint256 tokenABalance = tokenA.balanceOf(address(this));
            uint256 usdBalance = BUSD.balanceOf(address(this));
            tokenA.transfer(beneficiery,tokenABalance);
            BUSD.transfer(beneficiery,usdBalance);
        

    }// allow emergency withdrawl of Liquidity

    
}

