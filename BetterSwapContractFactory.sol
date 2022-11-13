pragma solidity >=0.8.0;

//SPDX-License-Identifier: UNLICENSED

import "./SimpleBetterSwapToken.sol";
import "./AutoLPBetterSwap.sol";

contract BetterSwapTokenFactory{

    address public owner;
    address public fundHolder;
    uint256 public fee;
    address USD;
    IBEP20 con;
    mapping(address=> address[]) public tokensCreatedByAddress;

    constructor(address _fundHolder){

        owner=msg.sender;
        fundHolder = _fundHolder;
        con = IBEP20(USD);
    }

    function setTokenCreationFee(uint256 feeAMT) external{
        require(msg.sender==owner,"You are not the father");
        fee = feeAMT*10**18;
    }

    function changeOwner(address newOwner) external{
        require(msg.sender==owner,"You are not the father");
        owner = newOwner;
    }

    function changeFundHolder(address holder) external{
        require(msg.sender==owner,"You are not the father");
        fundHolder = holder;
    }

    function createLPToken(string memory name, string memory symbol,
                            uint256 supply, uint256 buyTax, uint256 saleTax, uint256 LPtax) external returns(address){
                con.transferFrom(msg.sender,fundHolder,fee);
                AutoLPBetterSwap newContract = new AutoLPBetterSwap(name,symbol,supply,buyTax,saleTax,fundHolder,msg.sender,LPtax);

                tokensCreatedByAddress[msg.sender].push(address(newContract));
                return (address(newContract));
    }

    function createSimpleToken(string memory name, string memory symbol,
                            uint256 supply, uint256 buyTax, uint256 saleTax) external returns(address) {
                con.transferFrom(msg.sender,fundHolder,fee);
                BSimpleToken newContract = new BSimpleToken(name,symbol,supply,buyTax,saleTax,fundHolder,msg.sender);

                tokensCreatedByAddress[msg.sender].push(address(newContract));

                return (address(newContract));
    }




}