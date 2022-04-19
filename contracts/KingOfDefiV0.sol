// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
KingOfDefi V0 game
Rules:
1) Users can partecipate to the weekly defiWar
2) Every user will have the same amount of VUSD to trade
3) VUSD can be swapped for any v-asset supported by chainlink feeders oracles
4) The first on the leaderboard can stole the crown.
4) At the end of the week the crown holders can redeem the prize 
Every week will be a prize to win
*/

interface ICLH {
    function getLastUSDPrice(uint256) external view returns(uint256);
    function getUSDForAmount(uint256, uint256) external view returns(uint256);
    function oracleLastIndex() external view returns(uint256);
}

contract KingOfDefiV0 {

    using SafeERC20 for IERC20;

    mapping(address => mapping(uint256 => uint256)) public balances; // user => asset index => amount
    mapping(address => bool) public subscribed;
    mapping(address => uint256) public prizes;
    mapping(address => uint256) public lastAction;

    uint256 gameEnd = block.timestamp + 7 days;
    uint256 disputeTime = 1 days;
    uint256 actionDelay = 5 minutes;

    address king;
    address chainlinkHub;

    event Subscribed(address player);
    event Swapped(uint256 indexFrom, uint256 amountFrom, uint256 indexTo, uint256 amountTo);
    event PrizeRedeemed(address token, uint256 amount);
    event NewKing(address oldKing, uint256 oldKingUSD, address newKing, uint256 newKingUSD);
    event RewardAdded(address token, uint256 amount);

    constructor(address _chainlinkHub) {
        chainlinkHub = _chainlinkHub;
    }
    
    /// @notice subscribe to the game, one subscription for each address
    /// @dev it will give to the player 100K virtual-USD (VUSD)
    function play() external {
        require(!subscribed[msg.sender], "already subscribed");
        subscribed[msg.sender] = true;
        balances[msg.sender][0] = 100_000 * 10**18; // 0 is VUSD
        emit Subscribed(msg.sender);
    }

    /// @notice swap virtual asset to another virtual asset
    /// @dev the asset price will be fetched via chainlink oracles
	/// @param _fromIndex index of the token to swap from
    /// @param _toIndex index of tthe token to swap to
    /// @param _amount amount to swap from
    function swap(uint256 _fromIndex, uint256 _toIndex, uint256 _amount) external {
        require(block.timestamp > lastAction[msg.sender] + actionDelay, "action delay not elapsed");
        require(_fromIndex != _toIndex, "same index");
        require(_amount > 0, "set an amount > 0");
        require(balances[msg.sender][_fromIndex] >= _amount, "amount not enough");

        uint256 fromUSD;
        if(_fromIndex == 0) {
            fromUSD = _amount; // v-usd
        } else {
            fromUSD = ICLH(chainlinkHub).getUSDForAmount(_fromIndex, _amount);
        }
        
        uint256 toUSD;
        if(_toIndex == 0) {
            toUSD = 10**18; // v-usd
        } else {
            toUSD = ICLH(chainlinkHub).getLastUSDPrice(_toIndex) * 10**10;
        }

        uint256 amountToBuy = fromUSD * 10**18 / toUSD;

        unchecked{balances[msg.sender][_fromIndex] -= _amount;}
        balances[msg.sender][_toIndex] += amountToBuy;

        lastAction[msg.sender] = block.timestamp;

        emit Swapped(_fromIndex, _amount, _toIndex, amountToBuy);
    }

    /// @notice redeem prize, only the king can do that
    /// @dev it can be called only by the king after the dispute time
	/// @param _token token to redeem
    /// @param _amount amount to redeem
    function redeemPrize(address _token, uint256 _amount) external {
        require(block.timestamp > gameEnd + disputeTime, "Can't redeem yet");
        require(msg.sender == king, "Only the king");
        require(prizes[_token] >= _amount, "Amount too high");
        IERC20(_token).safeTransfer(msg.sender, _amount);
        unchecked{prizes[_token] -= _amount;} // skip underflow check
    }

    /// @notice steal the crown from the king, you can if you have more usd value
    /// @dev it can be called only during the crown dispute time
    function stealCrown() external {
        require(block.timestamp > gameEnd && block.timestamp < gameEnd + disputeTime, "only during dispute time");
        if (king == address(0)) {
            king = msg.sender;
            return;
        }
        uint256 actualKingUSD = calculateTotalUSD(king);
        uint256 rivalUSD = calculateTotalUSD(msg.sender);
        if (rivalUSD > actualKingUSD) {
            emit NewKing(king, actualKingUSD, msg.sender, rivalUSD);
            king = msg.sender;
        }
    }

    /// @notice calculate usd value of an asset
    /// @dev approve the token before calling the function
	/// @param _player player address
    /// @param _assetIndex index of the asset 
    function balanceOfInUSD(address _player, uint256 _assetIndex) external view returns(uint256) {
        uint256 amount = balances[_player][_assetIndex];
        return ICLH(chainlinkHub).getUSDForAmount(_assetIndex, amount);
    }

    /// @notice calculate total usd value of the player
	/// @param _player player address
    function calculateTotalUSD(address _player) public view returns(uint256) {
        uint256 usdTotalAmount;
        uint256 lastIndex = ICLH(chainlinkHub).oracleLastIndex();
        usdTotalAmount += balances[_player][0]; // v-usd
        for(uint256 index = 1; index < lastIndex; index++) {
            uint256 amount = balances[_player][index];
            if (amount > 0) {
                usdTotalAmount += ICLH(chainlinkHub).getUSDForAmount(index, amount);
            }
            
        }
        return usdTotalAmount;
    }

    /// @notice top up weekly prize with any ERC20 (until the game end)
    /// @dev approve the token before calling the function
	/// @param _token token to top up
    /// @param _amount amount to top up
    function topUpPrize(address _token, uint256 _amount) external {
        require(block.timestamp <= gameEnd, "match already ended");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        prizes[_token] += _amount;
        emit RewardAdded(_token, _amount);
    }
}