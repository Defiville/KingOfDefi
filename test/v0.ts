import { ethers, network } from "hardhat";
import { expect } from "chai";

import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "@ethersproject/contracts";
import { JsonRpcSigner } from "@ethersproject/providers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { parseEther } from "@ethersproject/units";

import SDTABI from "./fixtures/SDTABI.json";

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

const SDT = "0x361A5a4993493cE00f61C32d4EcCA5512b82CE90";
const SDTWHALE = "0x45d742a488392e2888523d12c5fd3c20f05d65b5";

describe("KingOfDefiV0", function () {
    let clh: Contract;
    let kod: Contract;
    let sdt: Contract;
    let deployer: SignerWithAddress;
    let player1: SignerWithAddress;
    let player2: SignerWithAddress;
    let player3: SignerWithAddress;
    let player4: SignerWithAddress;
    let sdtWhale: JsonRpcSigner;

    before(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();
        const CLH = await ethers.getContractFactory("ChainlinkHub");
        const KOD = await ethers.getContractFactory("KingOfDefiV0");
        const gameDuration =  60 * 60 * 24 * 7; // 7 days
        const disputeDuration = 60 * 60 * 24; // 1 day
        const swapDelay = 60 * 5; // 5 minutes
        sdt = await ethers.getContractAt(SDTABI, SDT);
        clh = await CLH.deploy();
        kod = await KOD.deploy(gameDuration, disputeDuration, swapDelay, clh.address);

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [SDTWHALE]
        });

        sdtWhale = await ethers.provider.getSigner(SDTWHALE);

        // add some oracles
        await clh.addOracle("0x443C5116CdF663Eb387e72C688D276e702135C87"); // 1 inch
        await clh.addOracles([
            "0x72484B12719E23115761D5DA1646945632979bB6", 
            "0x882554df528115a743c4537828DA8D5B58e52544",
            "0x5DB6e61B6159B20F068dc15A47dF2E5931b14f29",
            "0x03Bc6D9EFed65708D35fDaEfb25E87631a0a3437",
            "0xF626964Ba5e81405f47e8004F0b276Bb974742B5",
            "0xD106B538F2A868c28Ca1Ec7E298C3325E0251d66",
            "0x82a6c4AF830caa6c97bb504425f6A66165C2c26e",
            "0xc907E116054Ad103354f2D350FD2514433D57F6f",
            "0x2A8758b7257102461BC958279054e372C2b1bDE6"
        ]);

        await network.provider.send("hardhat_setBalance", [sdtWhale._address, parseEther("10").toHexString()]);

        // send SDT as reward
        const amountToSend = parseEther("10");
        await sdt.connect(sdtWhale).approve(kod.address, amountToSend);
        await kod.connect(sdtWhale).topUpPrize(sdt.address, amountToSend);
    });

    describe("ChainlinkHub", function() {
        it("should fetch the oracle description", async () => {
            const asset1Inch = await clh.assetDescription(1);
            const assetAave = await clh.assetDescription(2);
            expect(asset1Inch).eq("1INCH / USD");
            expect(assetAave).eq("AAVE / USD");
        });
    });

    describe("Play the game", function() {
        it("should subscribe to the game", async () => {
            await kod.connect(player1).play();
            const vusdPlayer1 = await kod["balances(address,uint256)"](player1.address, 0)
            expect(vusdPlayer1).eq(parseEther("100000"))
            await kod.connect(player2).play();
            const vusdPlayer2 = await kod["balances(address,uint256)"](player2.address, 0)
            expect(vusdPlayer2).eq(parseEther("100000"))
            await kod.connect(player3).play();
            const vusdPlayer3 = await kod["balances(address,uint256)"](player3.address, 0)
            expect(vusdPlayer3).eq(parseEther("100000"))
        });

        it("should swap v-usd", async () => {
            await kod.connect(player1).swap(0, 1, parseEther("100"));
            await expect(kod.connect(player1).swap(0, 1, parseEther("100"))).to.be.revertedWith("swap delay not elapsed");
            const v1INCHBalance = await kod["balances(address,uint256)"](player1.address, 1);

            await network.provider.send("evm_increaseTime", [60 * 5]);
            await network.provider.send("evm_mine", []);

            await kod.connect(player1).swap(0, 1, parseEther("100"));
            const vUSDBalance = await kod["balances(address,uint256)"](player1.address, 0);
            expect(vUSDBalance).eq(parseEther("99800"));
            
            const v2INCHBalance = await kod["balances(address,uint256)"](player1.address, 1);
        });

        it("should steal the crown", async () => {
            await expect(kod.connect(player1).stealCrown()).to.be.revertedWith("only during dispute time");
            await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]);
            await network.provider.send("evm_mine", []);
            // try to subscribe
            await expect(kod.connect(player4).play()).to.be.revertedWith("subscriptions closed");
            const usdPlayer1 = await kod.calculateTotalUSD(player1.address);
            const usdPlayer2 = await kod.calculateTotalUSD(player2.address);
            await kod.connect(player1).stealCrown();
            await kod.connect(player2).stealCrown();
        });

        it("the winner should claim the reward", async () => {
            const amountToRedeem = parseEther("10");
            await expect(kod.connect(player2).redeemPrize(sdt.address, amountToRedeem)).to.be.revertedWith("can't redeem yet");
            await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 1]);
            await network.provider.send("evm_mine", []);
            const sdtBefore = await sdt.balanceOf(player2.address)
            await kod.connect(player2).redeemPrize(sdt.address, amountToRedeem)
            const sdtAfter = await sdt.balanceOf(player2.address)
            expect(sdtAfter.sub(sdtBefore)).eq(amountToRedeem);
        });
    });
});