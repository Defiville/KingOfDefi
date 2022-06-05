// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
KingOfDefi V0 game
Rules:
1) Users can subscribe to the game for free, it gives 100K virtual-USD to the player.
2) Players can use the v-USD to buy other virtual assets, the pair rate price is fetched via the related chainlink oracle.
3) Players can swap virtual asset for the entire game period, there is only a delay to wait between swaps by the same player.
4) At the end of the game period, a new crown dispute period begins and players can start to steal the crown from other players.
5) The crown can be steal ONLY IF the actual USD value of the total virtual assets bought is higher than the actual crown holder usd value.
6) At the end of the dispute period, the king can redeem the prize.

Perp Version
At every new week (midnight on thursday) a new match will start 
*/

interface ICLH {
    function getLastUSDPrice(uint256) external view returns(uint256);
    function getUSDForAmount(uint256, uint256) external view returns(uint256);
    function oracleNextIndex() external view returns(uint256);
    function assetDescription(uint256) external view returns(string memory);
}

// Perpetual weekly game
contract KingOfDefiV0Perp {
    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public balances; // week match => user => asset index => amount
    mapping(uint256 => mapping(address => bool)) public subscribed; // week match => user => subscribed
    mapping(uint256 => mapping(address => uint256)) public prizes; // week match => token
    mapping(address => uint256) public lastSwap;
    mapping(uint256 => address) public kings;
    uint256[] public numberOfPlayers; // players for each week match 
    uint256 public gameWeek = block.timestamp / 1 weeks;

    // Game Parameter
    uint256 public constant disputeDuration = 1 days;
    uint256 public constant swapDelay = 2 minutes;
    uint256 public constant initialVUSD = 100_000;
    address public chainlinkHub; // game assets oracle hub

    // Game Events 
    event Subscribed(address indexed player, uint256 indexed gameWeek);
    event Swapped(
        uint256 indexed gameWeek,
        uint256 indexed indexFrom,
        uint256 indexed indexTo,
        uint256 amountFrom,
        uint256 amountTo
    );
    event PrizeRedeemed(
        address indexed king,
        uint256 indexed gameWeek,
        address indexed token, 
        uint256 amount
    );
    event NewKing(
        uint256 indexed gameWeek,
        address indexed oldKing,
        address indexed newKing,
        uint256 oldKingUSD,
        uint256 newKingUSD
    );
    event RewardAdded(
        uint256 indexed gameWeek,
        address indexed token, 
        uint256 amount
    );

    constructor( 
        address _chainlinkHub
    ) {
        chainlinkHub = _chainlinkHub;
    }

    modifier updateWeek() {
        uint256 currentGameWeek = block.timestamp / 1 weeks;
        if (currentGameWeek > gameWeek) {
            gameWeek = currentGameWeek;
        }
        _;
    }
    
    /// @notice subscribe to the game, one subscription for each address for each week match
    /// @dev it will give to the player 100K virtual-USD (VUSD)
    function play() external updateWeek() {
        require(!subscribed[gameWeek][msg.sender], "already subscribed");
        subscribed[gameWeek][msg.sender] = true;
        balances[gameWeek][msg.sender][0] = initialVUSD; // 0 is VUSD
        numberOfPlayers[gameWeek] += 1;
        emit Subscribed(msg.sender, gameWeek);
    }

    /// @notice swap virtual asset to another virtual asset (only during the game period)
    /// @dev the asset price will be fetched via chainlink oracles
	/// @param _fromIndex index of the token to swap from
    /// @param _toIndex index of the token to swap to
    /// @param _amount amount to swap
    function swap(uint256 _fromIndex, uint256 _toIndex, uint256 _amount) external updateWeek() {
        require(subscribed[gameWeek][msg.sender], "player not subscribed");
        require(block.timestamp < gameWeek + 1 weeks - disputeDuration, "crown dispute period");
        require(block.timestamp > lastSwap[msg.sender] + swapDelay, "player swap delay not elapsed");
        require(_fromIndex != _toIndex, "same index");
        require(_amount > 0, "set an amount > 0");

        uint256 lastIndex = ICLH(chainlinkHub).oracleNextIndex();
        require(_fromIndex < lastIndex && _toIndex < lastIndex, "only existing indexes");
        require(balances[gameWeek][msg.sender][_fromIndex] >= _amount, "amount not enough");

        uint256 fromUSD;
        uint256 toUSD;
        if (_toIndex == 0) {
            // v-asset <-> v-usd
            fromUSD = ICLH(chainlinkHub).getUSDForAmount(_fromIndex, _amount);
            toUSD = 1e18;
        } else {
            toUSD = ICLH(chainlinkHub).getLastUSDPrice(_toIndex);
            if(_fromIndex == 0) {
                // v-usd <-> v-asset
                fromUSD = _amount;
            } else {
                // v-asset <-> v-asset
                fromUSD = ICLH(chainlinkHub).getUSDForAmount(_fromIndex, _amount);
            }  
        }

        uint256 amountToBuy = fromUSD * 1e18 / toUSD;

        // swap
        unchecked{balances[gameWeek][msg.sender][_fromIndex] -= _amount;}
        balances[gameWeek][msg.sender][_toIndex] += amountToBuy;

        // store the actual ts to manage the swap delay
        lastSwap[msg.sender] = block.timestamp;

        emit Swapped(gameWeek, _fromIndex, _toIndex, _amount, amountToBuy);
    }

    /// @notice redeem prize, only the king can do that or anyone if no one became the king
    /// @dev it can be called only for a week match elapsed
    /// @param _gameWeek game week to redeem the prize
	/// @param _token token to redeem
    /// @param _amount amount to redeem
    function redeemPrize(uint256 _gameWeek, address _token, uint256 _amount) external updateWeek() {
        require(_gameWeek < gameWeek, "Week not elapsed");
        require(msg.sender == kings[_gameWeek] || kings[_gameWeek] == address(0), "not allowed");
        require(prizes[_gameWeek][_token] >= _amount, "amount too high");
        IERC20(_token).safeTransfer(msg.sender, _amount);
        unchecked{prizes[_gameWeek][_token] -= _amount;}
        emit PrizeRedeemed(msg.sender, gameWeek, _token, _amount);
    }

    /// @notice steal the crown from the king, you can if you have more usd value
    /// @dev it can be called only during the crown dispute time
    function stealCrown() external updateWeek() {
        require(block.timestamp > gameWeek + 1 weeks - disputeDuration, "only during dispute time");
        if (kings[gameWeek] == address(0)) {
            kings[gameWeek] = msg.sender;
            return;
        }
        uint256 actualKingUSD = calculateTotalUSD(kings[gameWeek]);
        uint256 rivalUSD = calculateTotalUSD(msg.sender);
        if (rivalUSD > actualKingUSD) {
            emit NewKing(gameWeek, kings[gameWeek], msg.sender, actualKingUSD, rivalUSD);
            kings[gameWeek] = msg.sender;
        }
    }

    /// @notice top up weekly prize with any ERC20 (until the game end)
    /// @dev approve the token before calling the function
	/// @param _token token to top up
    /// @param _amount amount to top up
    function topUpPrize(address _token, uint256 _amount) external updateWeek() {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        prizes[gameWeek][_token] += _amount;
        emit RewardAdded(gameWeek, _token, _amount);
    }

    /// @notice calculate usd value of an asset
    /// @dev approve the token before calling the function
	/// @param _player player address
    /// @param _assetIndex index of the asset 
    function balanceOfInUSD(address _player, uint256 _assetIndex) external view returns(uint256) {
        uint256 amount = balances[gameWeek][_player][_assetIndex];
        return ICLH(chainlinkHub).getUSDForAmount(_assetIndex, amount);
    }

    /// @notice calculate total usd value of the player for the current week
	/// @param _player player address
    function calculateTotalUSD(address _player) public view returns(uint256) {
        uint256 usdTotalAmount;
        uint256 nextIndex = ICLH(chainlinkHub).oracleNextIndex();
        usdTotalAmount += balances[gameWeek][_player][0]; // v-usd
        for(uint256 index = 1; index < nextIndex;) {
            uint256 amount = balances[gameWeek][_player][index];
            if (amount > 0) {
                usdTotalAmount += ICLH(chainlinkHub).getUSDForAmount(index, amount);
            }
            unchecked{++index;}
        }
        return usdTotalAmount;
    }

    /// @notice it returns the description of the asset (ETH / USD)
	/// @param _index index of the asset
    function getAssetFromIndex(uint256 _index) external view returns(string memory) {
        if (_index == 0) {
            return "VUSD";
        }
        return ICLH(chainlinkHub).assetDescription(_index);
    }
}