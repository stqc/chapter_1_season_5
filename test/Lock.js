const { expect } = require("chai");
const { ethers } = require("hardhat");

var deployer, testAC1, testAC2, testAC3, testAC4, testAC5, testAC6, testAC7,testAC8;
var deployer_, testAC1_, testAC2_, testAC3_, testAC4_, testAC5_, testAC6_, testAC7_,testAC8_;

var factoryABI= require("/home/prateek/Desktop/betterSwap/artifacts/contracts/betterSwapFacory.sol/betterSwapFactory.json");
var poolABI= require("/home/prateek/Desktop/betterSwap/artifacts/contracts/pool.sol/pool.json");
var ibep20ABI = require("/home/prateek/Desktop/betterSwap/artifacts/contracts/bep20.sol/IBEP20.json");
var tokenABI = require("/home/prateek/Desktop/betterSwap/artifacts/contracts/USD.sol/USD.json");
const { Test, test } = require("mocha");


var USD,TestToken,Factory,Pool;
var accounts =[deployer, testAC1, testAC2, testAC3, testAC4, testAC5, testAC6, testAC7,testAC8];
let num = ethers.utils.parseUnits("1000000", 18)
console.log(num)
describe("BetterSwap", async ()=> {
  before(async ()=>{
    accounts =  [deployer, testAC1, testAC2, testAC3, testAC4, testAC5, testAC6, testAC7,testAC8] = await ethers.getSigners();
    USD = await ethers.getContractFactory('USD');
    USD = await USD.deploy();
    Factory = await ethers.getContractFactory('betterSwapFactory');
    Factory = await Factory.deploy();
    TestToken = await ethers.getContractFactory('BEP20Ethereum');
    TestToken = await TestToken.deploy();
    deployer_ = await  TestToken.connect(deployer);
   
    await deployer_.transfer(testAC1.address,String(num));
    
    

    await Factory.connect(deployer).setUSD(USD.address);
  })
  it("Should not allow non admins to perform admin functions (setUSD,setFees,changeAdmin)", async()=>{
      let deployer_1 = await USD.connect(deployer);
      for( let i =1; i <accounts.length; i++){ 
        await deployer_1.transfer(accounts[i].address,String(num));
      }
        await expect(Factory.connect(testAC1).setUSD(TestToken.address)).to.be.revertedWith("You are not the admin");
        await expect(Factory.connect(testAC1).setFees(100)).to.be.revertedWith("You are not the admin");
        await expect( Factory.connect(testAC1).changeAdmin(TestToken.address)).to.be.revertedWith('You are not the admin')
        }
    
    
    )
    
it("should easily allow making of new pools but also disallow making of another pool of the same token", async()=>{
  
  await Factory.connect(testAC1).createNewPool(TestToken.address,testAC1.address,10,10);

  expect(await Factory.connect(deployer).poolExists(TestToken.address)==true);
  await expect(Factory.connect(testAC5).createNewPool(TestToken.address,testAC5.address,10,10)).to.be.revertedWith("Token pool already exists");
})

  it("should allow adding of LP by the pool beneficiary address and fail by any other address",async ()=>{
    
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    expect(tokenPool.address == poolAddress)
    await TestToken.connect(testAC1).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect(TestToken.connect(testAC1).allowance(testAC1.address,Factory.address)==ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC1).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect(USD.connect(testAC1).allowance(testAC1.address,Factory.address)==ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC1).addLiquidity(ethers.utils.parseUnits("50000",18),ethers.utils.parseUnits("25000",18));
    expect(await tokenPool.showPoolBalance()==[ethers.utils.parseUnits("50000",18),ethers.utils.parseUnits("25000",18)]);
    await TestToken.connect(deployer).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(deployer).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect (tokenPool.connect(deployer).addLiquidity(String(10000),String(5000))).to.be.revertedWith("You are not the project owner");
    console.log(await tokenPool.tokenPerUSD()/1e18+" Tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per token");
  });

  it("should fail adding LP at different price points when the price has already been set",async ()=>{

    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    await expect(tokenPool.connect(testAC1).addLiquidity(String(50000),String(50000))).to.be.revertedWith("Token to USD ratio missmatch");
    console.log(ethers.utils.parseUnits("2.5",18))
    
  });

  it("should allow buying of tokens from the LP and take 0.5% tax from the USD being sent for purchase (if there happens to be a token tax) and also take token tax from the LP",async()=>{
    let USDSpent = 500;
    let buyTax = 500*10/100;
    let fees = buyTax*10/100;
    buyTax-=fees;
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensBought = (USDSpent-buyTax-fees) * await tokenPool.tokenPerUSD()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address);
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress)/1e18;
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress)/1e18;

    await TestToken.connect(testAC2).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC2).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC2).buyToken(ethers.utils.parseUnits(String(USDSpent),18));
    await expect(TestToken.balanceOf(testAC2.address))==ethers.utils.parseUnits(String(amountOfTokensBought),18);
    await expect(USD.balanceOf(Factory.address)==ethers.utils.parseUnits(String(fees),18));
    await expect(USD.balanceOf(testAC1.address)==ethers.utils.parseUnits(String(balanceOFOwner+buyTax),18));
    let sbum = USDBalanceOfPool+USDSpent-buyTax-fees;
    await expect(tokenPool.showPoolBalance()==[ethers.utils.parseUnits(String(sbum),18),ethers.utils.parseUnits(String(tokenBalanceOfPool-amountOfTokensBought),18)]);

    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");
  })

  it("should allow buying of tokens from the LP and take 0.5% tax from the USD being sent for purchase (if there happens to be a token tax) and also take token tax from the LP",async()=>{
    let USDSpent = 1256;
    let buyTax = 1256*10/100;
    let fees = buyTax*10/100;
    buyTax-=fees
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensBought = (USDSpent-buyTax-fees) * await tokenPool.tokenPerUSD()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address)/1e18;
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress)/1e18;
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress)/1e18;

    let USDBalanceOFAdmin = await USD.balanceOf(Factory.address)/1e18;

    await TestToken.connect(testAC3).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC3).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC3).buyToken(ethers.utils.parseUnits(String(USDSpent),18));
    await expect(TestToken.balanceOf(testAC3.address))==ethers.utils.parseUnits(String(amountOfTokensBought),18);
    await expect(USD.balanceOf(Factory)==ethers.utils.parseUnits(String(USDBalanceOFAdmin+fees),18));
    await expect(USD.balanceOf(testAC1.address)==ethers.utils.parseUnits(String(balanceOFOwner+buyTax),18));
    await expect(tokenPool.showPoolBalance()==[ethers.utils.parseUnits(String(USDBalanceOfPool+(USDSpent-fees-buyTax))),ethers.utils.parseUnits(String(tokenBalanceOfPool-amountOfTokensBought))]);
    
    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");
  })

  it("should allow buying of tokens from the LP and take 0.5% tax from the USD being sent for purchase (if there happens to be a token tax) and also take token tax from the LP",async()=>{
    let USDSpent = 9500;
    let buyTax = USDSpent*10/100;
    let fees = buyTax*10/100;
    buyTax-=fees
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensBought = (USDSpent-buyTax-fees) * await tokenPool.tokenPerUSD()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address)/1e18;
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress)/1e18;
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress)/1e18;

    let USDBalanceOFAdmin = await USD.balanceOf(Factory.address)/1e18;

    await TestToken.connect(testAC4).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC4).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC4).buyToken(ethers.utils.parseUnits(String(USDSpent),18));
    await expect(TestToken.balanceOf(testAC4.address))==ethers.utils.parseUnits(String(amountOfTokensBought),18);
    await expect(USD.balanceOf(Factory)==ethers.utils.parseUnits(String(USDBalanceOFAdmin+fees),18));
    await expect(USD.balanceOf(testAC1.address)==ethers.utils.parseUnits(String(balanceOFOwner+buyTax),18));
    await expect(tokenPool.showPoolBalance()==[ethers.utils.parseUnits(String(USDBalanceOfPool+(USDSpent-fees-buyTax))),ethers.utils.parseUnits(String(tokenBalanceOfPool-amountOfTokensBought))]);
    
    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");
  })

  it("should allow buying of tokens from the LP and take 0.5% tax from the USD being sent for purchase (if there happens to be a token tax) and also take token tax from the LP",async()=>{
    let USDSpent = 15000;
    let buyTax = USDSpent*10/100;
    let fees = buyTax*10/100;
    buyTax-=fees
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensBought = (USDSpent-buyTax-fees) * await tokenPool.tokenPerUSD()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address)/1e18;
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress)/1e18;
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress)/1e18;

    let USDBalanceOFAdmin = await USD.balanceOf(Factory.address)/1e18;

    await TestToken.connect(testAC5).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC5).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC5).buyToken(ethers.utils.parseUnits(String(USDSpent),18));
    await expect(TestToken.balanceOf(testAC5.address))==ethers.utils.parseUnits(String(amountOfTokensBought),18);
    await expect(USD.balanceOf(Factory)==ethers.utils.parseUnits(String(USDBalanceOFAdmin+fees),18));
    await expect(USD.balanceOf(testAC1.address)==ethers.utils.parseUnits(String(balanceOFOwner+buyTax),18));
    await expect(tokenPool.showPoolBalance()==[ethers.utils.parseUnits(String(USDBalanceOfPool+(USDSpent-fees-buyTax))),ethers.utils.parseUnits(String(tokenBalanceOfPool-amountOfTokensBought))]);
    
    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");
  })
  
  it("should fail to buy more than 85% of the tokens in the pool",async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    await expect(tokenPool.connect(testAC2).buyToken(ethers.utils.parseUnits(String(45000),18))).to.be.revertedWith("It seems there is insufficient liquidity");
  })
  
  it("should allow selling of the tokens bought taking 0.5% fee (if there is just a sale tax) along with the sale tax",async()=>{
    
    let TokensToSell = 100;
    let saleTax = TokensToSell*10/100;
    let fees = saleTax*10/100;
    saleTax-=fees
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensSold = (TokensToSell-saleTax-fees) * await tokenPool.USDPerToken()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address);
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress);
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress);

    let USDBalanceOFAdmin = await USD.balanceOf(Factory.address);

    await TestToken.connect(testAC5).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC5).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC5).sellToken(TokensToSell);
    await expect(USD.balanceOf(testAC5.address))==await USD.balanceOf(testAC5.address)+amountOfTokensSold;
    await expect(USD.balanceOf(Factory.address)==USDBalanceOFAdmin+fees);
    await expect(USD.balanceOf(testAC1.address)==(balanceOFOwner+saleTax));
    await expect(tokenPool.showPoolBalance()==[String(USDBalanceOfPool+(TokensToSell-fees-saleTax)),String(tokenBalanceOfPool+amountOfTokensSold)]);
    
    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");

  })

  it("should allow selling of the tokens bought taking 0.25% fee (if there is just a sale tax) along with the sale tax",async()=>{
    
    let TokensToSell = 1000;
    let saleTax = TokensToSell*10/100;
    let fees = saleTax*10/100;
    saleTax-=fees
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    let amountOfTokensSold = (TokensToSell-saleTax-fees) * await tokenPool.USDPerToken()/1e18;
    let balanceOFOwner=await USD.balanceOf(testAC1.address);
    
    let USDBalanceOfPool = await USD.balanceOf(poolAddress);
    let tokenBalanceOfPool = await TestToken.balanceOf(poolAddress);

    let USDBalanceOFAdmin = await USD.balanceOf(Factory.address);

    await TestToken.connect(testAC3).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC3).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await tokenPool.connect(testAC3).sellToken(TokensToSell);
    await expect(USD.balanceOf(testAC3.address))==await USD.balanceOf(testAC3.address)+amountOfTokensSold;
    await expect(USD.balanceOf(Factory.address)==USDBalanceOFAdmin+fees);
    await expect(USD.balanceOf(testAC1.address)==(balanceOFOwner+saleTax));
    await expect(tokenPool.showPoolBalance()==[String(USDBalanceOfPool+(TokensToSell-fees-saleTax)),String(tokenBalanceOfPool+amountOfTokensSold)]);
    
    console.log(await tokenPool.showPoolBalance())
    console.log(await tokenPool.tokenPerUSD()/1e18+" tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per Token");
    
  })

  it("should allow chainging beneficiery address of any pool by the admin and fail by any other address",async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);  
    await Factory.connect(deployer).changeBeneficieryAddress(poolAddress,testAC2.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    await expect(tokenPool.beneficiery()==testAC2.address);
    await expect( Factory.connect(testAC1).changeBeneficieryAddress(poolAddress,testAC2.address)).to.be.revertedWith("You are not the admin");
    await expect( Factory.connect(testAC2).changeBeneficieryAddress(poolAddress,testAC2.address)).to.be.revertedWith("You are not the admin");
  });

  it("should allow new beneficiery to add liquidity and fail when any other address tries to", async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    expect(tokenPool.address == poolAddress)
    await TestToken.connect(testAC2).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect(TestToken.connect(testAC2).allowance(testAC1.address,Factory.address)==ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(testAC2).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect(USD.connect(testAC2).allowance(testAC1.address,Factory.address)==ethers.utils.parseUnits("99999999999999999999999999999999999999",18));

    var tokenPrice = await tokenPool.tokenPerUSD();
    console.log(tokenPrice)
    var poolBalance = await tokenPool.showPoolBalance();
    await tokenPool.connect(testAC2).addLiquidity(String(tokenPrice),String(1e18));
    expect(await tokenPool.showPoolBalance()==[poolBalance[0]+=tokenPrice,poolBalance[1]+=1e18]);
    await TestToken.connect(deployer).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await USD.connect(deployer).approve(poolAddress,ethers.utils.parseUnits("99999999999999999999999999999999999999",18));
    await expect (tokenPool.connect(deployer).addLiquidity(String(tokenPrice),String(1e18))).to.be.revertedWith("You are not the project owner");
    console.log(await tokenPool.tokenPerUSD()/1e18+" Tokens per USD");
    console.log(await tokenPool.USDPerToken()/1e18+" USD per token");
  })

  it("should not allow to change beneficiery from the pool directly",async ()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);

    await expect(tokenPool.connect(deployer).changeBeneficieryAddress(testAC1.address)).to.be.revertedWith("You are not the project owner or admin");
    await expect(tokenPool.connect(testAC2).changeBeneficieryAddress(testAC1.address)).to.be.revertedWith("You are not the project owner or admin");
    
  })

  it("should allow project owner to apply for emergency withdral of tokens but fail when they try to do it twice to bypass admin approval",async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);

    await tokenPool.connect(testAC2).approveEmergencyWithdraw();
    await expect(tokenPool.emergencyWithdrawApproved(testAC2)==true)

    await expect(tokenPool.connect(testAC2).approveEmergencyWithdraw()).to.be.revertedWith("You have already voted");
    
  })

  it("should not allow the swap admin to approve emergency withdraw from the token pool directly", async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);

    await expect(tokenPool.connect(deployer).approveEmergencyWithdraw()).to.be.revertedWith("You are not the project owner or admin");
 
  })

  it("should automatically fix the pool when extra tokens or usd is sent directly to the pool address instead of through the addLiquidity method", async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var poolUSD = await USD.balanceOf(poolAddress);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);
    var currentPrice = await tokenPool.USDPerToken();
    console.log(await USD.balanceOf(tokenPool.address));
    console.log(await USD.balanceOf(Factory.address)/1e18);
    await USD.connect(deployer).transfer(poolAddress,ethers.utils.parseUnits("1000",18));
    
    await expect(USD.balanceOf(poolAddress)==poolUSD+ethers.utils.parseUnits("1000",18));
    await expect(currentPrice==tokenPool.USDPerToken());
    var currentAc3Bal =await USD.balanceOf(testAC3.address);
    var currentAdminBal = await USD.balanceOf(Factory.address);
    await tokenPool.connect(testAC3).buyToken(ethers.utils.parseUnits("2500",18));
    await expect(USD.balanceOf(testAC3)==currentAc3Bal-ethers.utils.parseUnits("2500",18));
    await expect(USD.balanceOf(Factory.address)==currentAdminBal+ethers.utils.parseUnits("1000",18));

    console.log(await USD.balanceOf(tokenPool.address));
    console.log(await USD.balanceOf(Factory.address)/1e18);

  }
  )

  it("should not allow adding lp through the addLPfromPresale method",async ()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);

    await expect(tokenPool.connect(deployer).addLPfromPresale("100","100")).to.be.revertedWith("Only presale router may execute this function");
  })

  it("Should now allow any address except the admin to withdrawlALLUSD in the contract", async()=>{
    await expect(Factory.connect(testAC6).withdrawALLUSD()).to.be.revertedWith("You are not the admin");
    var usdBal = await USD.balanceOf(deployer.address);
    await Factory.connect(deployer).withdrawALLUSD();
    await expect(USD.balanceOf(deployer.address)>usdBal);
  })

  it("should not allow any address to approve emergency approval expect the admin",async ()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    await expect(Factory.connect(testAC1).approveEmergencyWithdraw(poolAddress)).to.be.revertedWith("You are not the admin");
    
    var balOFUSDPool = await USD.balanceOf(poolAddress);
    var balOftokenPool = await TestToken.balanceOf(poolAddress);
    var balUSDofOwner = await USD.balanceOf(testAC2.address);
    var balTokenOfOwner = await TestToken.balanceOf(testAC2.address);

    await Factory.connect(deployer).approveEmergencyWithdraw(poolAddress);
    await expect(USD.balanceOf(poolAddress)==0 && TestToken.balanceOf(poolAddress)==0);
    await expect(USD.balanceOf(testAC2)==balUSDofOwner+balOFUSDPool && TestToken.balanceOf(testAC2)==balTokenOfOwner+balOftokenPool)
  })

  it("should fail swapping when the LP is removed", async()=>{
    var poolAddress = await Factory.connect(testAC1).TokenToPool(TestToken.address);
    var tokenPool = new ethers.Contract(poolAddress,poolABI,ethers.provider);

    await expect(tokenPool.connect(testAC3).sellToken("1000")).to.be.revertedWith("The pool has been tampered with and needs to be fixed inorder to be usable again please ask the project owner to add the exact amount of tokens back");
    console.log(await USD.balanceOf(poolAddress));
    console.log(await TestToken.balanceOf(poolAddress));
  })
  }

  
);