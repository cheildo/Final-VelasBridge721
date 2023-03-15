// SPDX-License-Identifier: MIT LICENSE



pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract bridgeCustody is IERC721Receiver, ReentrancyGuard, Ownable {
// contract Custody is IERC1155Receiver, ReentrancyGuard, Ownable {

  uint256 public costCustom = 1 ether;
  uint256 public costNative = 0.0000075 ether;

  struct Custody {
    uint256 [] tokenId;
  }

  mapping(address => Custody) holdCustody;

  event NFTCustody (
    uint256 [] indexed tokenId,
    address holder
  );


  ERC721Enumerable nft;
  // IERC1155 public nft;
  IERC20 public paytoken;

   constructor(ERC721Enumerable _nft) {
    nft = _nft;
  }

  function retainNFTN(uint256[] memory tokenIds) public payable nonReentrant {
      require(msg.value == costNative, "Not enough balance to complete transaction.");
      // require(tokenIds.length == amounts.length, "ERC1155: ids and amounts length mismatch");
    
      holdCustody[msg.sender] =  Custody(tokenIds);
      // nft.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");
      for(uint256 i=0 ; i<tokenIds.length ; i++) {
        nft.safeTransferFrom(msg.sender, address(this), tokenIds[i], "");
      }
      emit NFTCustody(tokenIds, msg.sender);
  }

 
 function releaseNFT(address wallet, uint256[] memory tokenIds) public nonReentrant onlyOwner() {
      
      // nft.safeBatchTransferFrom(address(this), wallet, tokenIds, amounts, "");
      for(uint256 i=0 ; i<tokenIds.length ; i++) {
        nft.safeTransferFrom(address(this), wallet, tokenIds[i], "");
      }
      delete holdCustody[wallet];
 }

  function emergencyDelete(address user) public nonReentrant onlyOwner() {
      delete holdCustody[user];
 }

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      //require(from == address(0x0), "Cannot Receive NFTs Directly");
      return IERC721Receiver.onERC721Received.selector;
  }


  function withdrawNative() public payable onlyOwner() {
    require(payable(msg.sender).send(address(this).balance));
    }
  
}