pragma solidity >=0.8.0;
 //SPDX-License-Identifier: UNLICENSED

 import "./pool.sol";
 import "./betterFactoryInterface.sol";
 import "./bep20.sol";


contract betterSwapFactory is factoryMethod{

     address public admin;
     mapping(address=>address) public TokenToPool;
     mapping(address=>bool) public poolExists;
     address[] public allTokens;
     address public usd;
     uint256 public Platformfee;
     uint256 public Beneficieryfee;

    constructor(){
        admin = msg.sender;
        Platformfee = 25;
        Beneficieryfee = 25;
    }



    function changeAdmin(address newAdmin) external {
        require(msg.sender==admin,"You are not the admin");
        admin = newAdmin;
    }

    function setUSD(address add)external{
        require(msg.sender==admin,"You are not the admin");
        usd = add;
    }
    
    function showFees()external view override returns(uint256,uint256){
        return (Platformfee,Beneficieryfee);    
    }

    function createNewPool(address token, address beneficiery, uint256 buyTax, uint256 saleTax) external override{
        require(!poolExists[token],"Token pool already exists");
        pool p = new pool(token,beneficiery,buyTax,saleTax,usd,address(this),address(this));
        allTokens.push(token);
        TokenToPool[token] = address(p);
        poolExists[token]=true;

    }

    function setFees(uint256 Pfee, uint256 Bfee) external{
        require(msg.sender==admin,"You are not the admin");
        Platformfee =Pfee;
        Beneficieryfee = Bfee;
    }

    function approveEmergencyWithdraw(address poolAdd) external{
        require(msg.sender==admin,"You are not the admin");
        pool p = pool(poolAdd);
        p.approveEmergencyWithdraw();
    }

    function changeBeneficieryAddress(address pool_,address ben) external{
        require(msg.sender == admin,"You are not the admin");
        pool p = pool(pool_);
        p.changeBeneficieryAddress(ben);
    }

    function withdrawALLUSD() external{
        require(msg.sender==admin,"You are not the admin");
        IBEP20 USD = IBEP20(usd);
        USD.transfer(admin,USD.balanceOf(address(this)));
    }
 }
