// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// asset index
// 1 - 1inch/usd 0x443C5116CdF663Eb387e72C688D276e702135C87
// 2 - aave/usd 0x72484B12719E23115761D5DA1646945632979bB6
// 3 - ada/usd 0x882554df528115a743c4537828DA8D5B58e52544
// 4 - alcx/usd 0x5DB6e61B6159B20F068dc15A47dF2E5931b14f29
// 5 - algo/usd 0x03Bc6D9EFed65708D35fDaEfb25E87631a0a3437
// 6 - badger/usd 0xF626964Ba5e81405f47e8004F0b276Bb974742B5
// 7 - bal/usd 0xD106B538F2A868c28Ca1Ec7E298C3325E0251d66
// 8 - bnb/usd 0x82a6c4AF830caa6c97bb504425f6A66165C2c26e
// 9 - btc/usd 0xc907E116054Ad103354f2D350FD2514433D57F6f
// 10 - comp/usd 0x2A8758b7257102461BC958279054e372C2b1bDE6
// 11 - crv/usd 0x336584C8E6Dc19637A5b36206B1c79923111b405
// 12 - cvx/usd 0x5ec151834040B4D453A1eA46aA634C1773b36084
// 13 - doge/usd 0xbaf9327b6564454F4a3364C33eFeEf032b4b4444
// 14 - dot/usd 0xacb51F1a83922632ca02B25a8164c10748001BdE
// 15 - eth/usd 0xF9680D99D6C9589e2a93a78A04A279e509205945
// 16 - ftm/usd 0x58326c0F831b2Dbf7234A4204F28Bba79AA06d5f
// 17 - fxs/usd 0x6C0fe985D3cAcbCdE428b84fc9431792694d0f51
// 18 - ghst/usd 0xDD229Ce42f11D8Ee7fFf29bDB71C7b81352e11be
// 19 - link/usd 0xd9FFdb71EbE7496cC440152d43986Aae0AB76665
// 20 - matic/usd 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0

interface IOracle {
    function latestAnswer() external view returns(uint256);
    function decimals() external view returns(uint256);
    function description() external view returns(string memory);
}

contract ChainlinkHub {

    mapping(uint256 => address) public oracles; // chainlink oracles addresses
    uint256 public oracleNextIndex = 1; // it starts from 1 because the 0 index is v-usd
    address public governance;

    event OracleAdded(address oracle);
    event GovernanceChanged(address oldG, address newG);

    constructor() {
        governance = msg.sender;
    }

    /// @notice add new oracles to the hub
	/// @param _oracles oracle addresses
    function addOracles(address[] memory _oracles) external {
        require(msg.sender == governance, "!gov");
        for (uint256 i = 0; i < _oracles.length; i++) {
            _addOracle(_oracles[i]);
        }
    }

    /// @notice add new oracle to the hub
	/// @param _oracle oracle address
    function addOracle(address _oracle) external {
        require(msg.sender == governance, "!gov");
        _addOracle(_oracle);
    }

    /// @notice internal function to add a new oracle to the hub
	/// @param _oracle oracle address
    function _addOracle(address _oracle) internal {
        require(_oracle != address(0));
        oracles[oracleNextIndex] = _oracle;
        oracleNextIndex++;
        emit OracleAdded(_oracle);
    }

    /// @notice get the last USD price for the asset
	/// @param _assetIndex index of the asset
    function getLastUSDPrice(uint256 _assetIndex) external view returns(uint256) {
        address oracle = oracles[_assetIndex];
        return IOracle(oracle).latestAnswer() * (1e18 / 10**IOracle(oracle).decimals());
    }

    /// @notice add new oracle to the hub
	/// @param _assetIndex oracle address
    /// @param _amount asset amount
    function getUSDForAmount(uint256 _assetIndex, uint256 _amount) external view returns(uint256) {
        address oracle = oracles[_assetIndex];
        uint256 usdValue = IOracle(oracle).latestAnswer();
        return usdValue * _amount / 10**IOracle(oracle).decimals();
    }

    /// @notice get the asset description
	/// @param _assetIndex oracle address
    function assetDescription(uint256 _assetIndex) external view returns(string memory) {
        address oracle = oracles[_assetIndex];
        return IOracle(oracle).description();
    }

    /// @notice set the governance
	/// @param _governance governance address
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!gov");
        emit GovernanceChanged(governance, _governance);
        governance = _governance;
    }
}