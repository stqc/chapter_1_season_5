pragma solidity ^0.8.0;
//SPDX-License-Identifier: UNLICENSED


import "./poolMethods.sol";
import "./safemath.sol";
import "./bep20.sol";
import "./betterFactoryInterface.sol";


contract pool is poolMethods{
    using SafeMath for uint256;

    address public beneficiery;
    uint256 public tokenInPool;
    uint256 public USDinPool;
    uint256 public buyTax;
    uint256 public saleTax;
    address public admin;
    address public presaleRouter;
    address public tokenAddress;
    address public BUSDAddress;
    address public factory;
    bool public priceSet=false;
    uint256 platformFee;
    mapping(address=>bool) public emergencyWithdrawApproved;
    bool isActive =false;
    uint256 emergencyWithdrawSigned=0;
    factoryMethod immutable fact;

    constructor(address token, address beneficieryA,uint256 buy, uint256 sale, address usd,address factoryAdd, address admin_){
        tokenAddress =token;
        beneficiery = beneficieryA;
        factory = factoryAdd;
        buyTax =buy;
        saleTax =sale;
        BUSDAddress =usd;
        fact = factoryMethod(factory);
        admin = admin_;
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
        require(msg.sender==admin ,"You are not the project owner or admin");
        _;
    }

    modifier onlyPresale{
        require(msg.sender==presaleRouter,"Only presale router may execute this function");
        _;
    }

    modifier occupied{
        require(!isActive,"A transaction is already in process please wait");
        isActive=true;
        _;
        isActive =false;
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

    function buyToken(uint256 amount) external override occupied{
        require(amount.mul(tokenPerUSD()).div(10**18)<(tokenInPool.mul(85)).div(100),"It seems there is insufficient liquidity");
        IBEP20 token = IBEP20(tokenAddress);
        IBEP20 BUSD = IBEP20(BUSDAddress);
            
        skim();

        require(tokenInPool==token.balanceOf(address(this)) && USDinPool==BUSD.balanceOf(address(this)),"The pool has been tampered with and needs to be fixed inorder to be usable again please ask the project owner to add the exact amount of tokens back");

        platformFee = fact.showFees();

        uint256 TokenPerUSD = tokenPerUSD();
        
        uint256 taxFromTheBuy = (amount.mul(buyTax)).div(100);

        amount = amount.sub(taxFromTheBuy);

        uint256 platformTax =(taxFromTheBuy.mul(platformFee)).div(100);

        taxFromTheBuy = taxFromTheBuy.sub(platformTax);

        uint256 finalTokensGiven = amount.mul(TokenPerUSD);

        BUSD.transferFrom(msg.sender,address(this),amount);
        BUSD.transferFrom(msg.sender,beneficiery,taxFromTheBuy);
        BUSD.transferFrom(msg.sender, admin, platformTax);
        token.transfer(msg.sender,finalTokensGiven.div(10**18));
        

        USDinPool=BUSD.balanceOf(address(this));
        tokenInPool = token.balanceOf(address(this));


    } //buy the token from the said pool

    function sellToken(uint256 amount) override external occupied {
        require(amount.mul(USDPerToken()).div(10**18)<(USDinPool.mul(85)).div(100),"It seems there is insufficient liquidity");
        IBEP20 token = IBEP20(tokenAddress);
        IBEP20 BUSD = IBEP20(BUSDAddress);
        
        skim();

        require(tokenInPool==token.balanceOf(address(this)) && USDinPool==BUSD.balanceOf(address(this)),"The pool has been tampered with and needs to be fixed inorder to be usable again please ask the project owner to add the exact amount of tokens back");

        token.transferFrom(msg.sender,address(this),amount);
        
        platformFee = fact.showFees();
        
        uint256 USDperToken = USDPerToken();

        uint256 taxFromTheSell = (amount.mul(saleTax)).div(100);

        amount = amount.sub(taxFromTheSell);

        uint256 platformTax = (taxFromTheSell.mul(platformFee)).div(100);

        taxFromTheSell = taxFromTheSell.sub(platformTax);

        uint256 finalUSDToGive = (amount.mul(USDperToken));    

        BUSD.transfer(beneficiery,(taxFromTheSell.mul(USDperToken)).div(10**18));
       
        BUSD.transfer(admin,(platformTax.mul(USDperToken)).div(10**18));
       
        
        BUSD.transfer(msg.sender,finalUSDToGive.div(10**18));

        USDinPool=BUSD.balanceOf(address(this));
        tokenInPool = token.balanceOf(address(this));


    } //sell the token back to said pool

    function addLiquidity(uint256 tokenAmount, uint256 USDAmount) external onlyProjectOwner occupied {
        
        if(priceSet){
            
            uint256 tokensRequired = USDAmount.mul(tokenPerUSD());
            
            require(tokenAmount==tokensRequired.div(10**18),"Token to USD ratio missmatch");
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

    function changeBeneficieryAddress(address ben) external onlyAdmin{
        beneficiery=ben;
    }

    function approveEmergencyWithdraw() external override onlyAdminAndProjectOwner occupied {
        require(!emergencyWithdrawApproved[msg.sender],"You have already voted");
        emergencyWithdrawApproved[msg.sender]=true;
        emergencyWithdrawSigned+=1;

        if(emergencyWithdrawSigned==2){
           
            IBEP20 tokenA = IBEP20(tokenAddress);
            IBEP20 BUSD = IBEP20(BUSDAddress);
            uint256 tokenABalance = tokenA.balanceOf(address(this));
            uint256 usdBalance = BUSD.balanceOf(address(this));
            tokenA.transfer(beneficiery,tokenABalance);
            BUSD.transfer(beneficiery,usdBalance);
        }

    }// allow emergency withdrawl of Liquidity

    function addLPfromPresale(uint256 tokenAmount,uint256 USDAmount) external onlyPresale occupied{

         if(priceSet){
            
            uint256 tokensRequired = USDAmount.mul(tokenPerUSD());
            
            require(tokenAmount==tokensRequired,"Token to USD ratio missmatch");
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
}

