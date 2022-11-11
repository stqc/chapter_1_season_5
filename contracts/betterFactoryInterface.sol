pragma solidity >=0.8.0;
//SPDX-License-Identifier: UNLICENSED
interface factoryMethod{
 
    function createNewPool(address,address,uint256,uint256) external;
    function showFees() external view returns(uint256,uint256);

}