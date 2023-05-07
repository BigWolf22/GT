// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract GoverlaToken is ERC20, ERC20Snapshot, Ownable, Pausable {
     using SafeMath for uint256;
     AggregatorV3Interface internal priceFeed;

     address public treasuryWallet = 0x14400987d7a7Bd01D8EDf01249Db7b3c4B60b9C2;
     uint256 public constant TREASURY_FEE = 2;
     uint256 public constant STABILIZATION_FEE = 30;

     event Lock(address indexed _address, uint256 _amount, uint256 _releaseTime);
     event Convert(address indexed _address, uint256 _amount);

     struct LockInfo {
        uint256 amount;
        uint256 releaseTime;
         }

     mapping(address => LockInfo) public lockedTokens;

    constructor() ERC20("Goverla Token", "GT") {
        _mint(treasuryWallet, 1000000 * 10**decimals());
     }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);

        if (lockedTokens[from].amount > 0 && block.timestamp >= lockedTokens[from].releaseTime) {
            lockedTokens[from].amount = 0;
            lockedTokens[from].releaseTime = 0;
         }
     }

    function _transfer(address sender, address recipient, uint256 amount) internal override whenNotPaused {
     uint256 fee = amount.mul(TREASURY_FEE).div(100);
     uint256 amountToTransfer = amount.sub(fee);

     require(amountToTransfer <= balanceOf(sender).sub(lockedTokens[sender].amount), "Transfer amount exceeds unlocked balance");

     // Стабілізаційна подушка
     int256 priceChangePercent = get24hPriceChangePercent();
         if (priceChangePercent > 20) {
         uint256 stabilizationFee = amount.mul(STABILIZATION_FEE).div(100);
         amountToTransfer = amountToTransfer.sub(stabilizationFee);
         _burn(sender, stabilizationFee);
         } else if (priceChangePercent < -20) {
             uint256 stabilizationReward = amount.mul(STABILIZATION_FEE).div(100);
             amountToTransfer = amountToTransfer.add(stabilizationReward);
             _mint(sender, stabilizationReward);
             }

     super._transfer(sender, treasuryWallet, fee);
     super._transfer(sender, recipient, amountToTransfer);
     }


    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
     }

    function lockTokens(address _address, uint256 _amount, uint256 _releaseTime) public onlyOwner {
        require(_address != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_releaseTime > block.timestamp, "Release time must be in the future");

        lockedTokens[_address].amount = lockedTokens[_address].amount.add(_amount);
        lockedTokens[_address].releaseTime = _releaseTime;

        emit Lock(_address, _amount, _releaseTime);
     }

    function snapshot() public onlyOwner {
        _snapshot();
     }

    function pause() public onlyOwner {
        _pause();
     }

    function unpause() public onlyOwner {
        _unpause();
     }

    function get24hPriceChangePercent() public view returns (int256) {
     (, int256 priceToday, , , ) = priceFeed.latestRoundData();
     (, int256 priceYesterday, , , ) = priceFeed.getRoundData(uint80(block.timestamp - 1 days));
     return ((priceToday - priceYesterday) * 100) / priceYesterday;
     }



    function generateRandomNumber() public view returns (int256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp))) % 101;
        if (random < 50) {
            return int256(random) * -1;
         } else {
            return int256(random);
          }
     }
 }

