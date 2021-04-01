// Copyright (C) 2020 Centrifuge
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.5.15 <0.6.0;

interface TinlakeRootLike {
    function relyContract(address, address) external;
}

interface SeniorTrancheLike {
    function currency() external returns(address);
    function token() external returns(address);
    function totalRedeem() external returns (uint);
    function totalSupply() external returns (uint);
    function closeEpoch() external returns  (uint totalSupplyCurrency_, uint totalRedeemToken_);
    function epochUpdate(uint epochID, uint supplyFulfillment_, uint redeemFulfillment_, uint tokenPrice_, uint epochSupplyOrderCurrency, uint epochRedeemOrderCurrency) external;
    function depend(bytes32 name, address addr) external;

    function supplyOrder(address usr, uint newSupplyAmount) external;
    function redeemOrder(address usr, uint newRedeemAmount) external;
}

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function mint(address, uint) external;
    function burn(address, uint) external;
    function totalSupply() external view returns (uint);
    function approve(address usr, uint amount) external;
}

contract ERC20Dummy {
    mapping (address => uint) public balanceOf;
    uint public totalSupply;

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "math-sub-underflow");
    }

    // --- ERC20 ---
    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad)
    public returns (bool)
    {
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        return true;
    }
    function mint(address usr, uint wad) external  {
        balanceOf[usr] = add(balanceOf[usr], wad);
        totalSupply    = add(totalSupply, wad);
    }
}

contract TinlakeSpell {
    // --- Math ---
    function safeAdd(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-add-overflow");
    }
    function safeSub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "math-sub-underflow");
    }


    bool public done;
    string constant public description = "Tinlake Mainnet Spell";

    // NS2 ROOT
    address constant public ROOT = 0x53b2d22d07E069a3b132BfeaaD275b10273d381E;
    address constant public SENIOR_TRANCHE = 0xfB30B47c47E2fAB74ca5b0c1561C2909b280c4E5;

    ERC20Like dai;
    ERC20Like drop;

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        execute();
    }

    // function signatures of reserve contract
    function deposit(uint amount) external {}
    function payout(uint amount) external {}
    function totalBalanceAvailable() external returns (uint) {return 0;}

    function execute() internal {
        // helper variables
        TinlakeRootLike root = TinlakeRootLike(address(ROOT));
        SeniorTrancheLike seniorTranche = SeniorTrancheLike(SENIOR_TRANCHE);
        ERC20Like dai = ERC20Like(seniorTranche.currency());
        ERC20Like drop = ERC20Like(seniorTranche.token());

        // spell needs to be a ward
        root.relyContract(address(seniorTranche), address(this));


        // dai amount we want to move into the spell
        uint daiBalance = dai.balanceOf(SENIOR_TRANCHE);


        // step 1: make totalSupply equal to DAI balance
        uint daiDelta = safeSub(daiBalance, seniorTranche.totalSupply());
        ERC20Dummy daiDummy = new ERC20Dummy();
        daiDummy.mint(address(1), daiDelta);

        seniorTranche.depend("currency", address(daiDummy));
        seniorTranche.supplyOrder(address(1), daiDelta);
        seniorTranche.depend("currency", address(dai));
        require(seniorTranche.totalSupply() == dai.balanceOf(SENIOR_TRANCHE), "totalSupply not equal dai balance");
        seniorTranche.closeEpoch();


        // spell needs to reserve
        seniorTranche.depend("reserve", address(this));

        seniorTranche.epochUpdate(10000, 10**27, 0, 1 ether, daiBalance, 0);
        // senior tranche gave approval to spell
        dai.transferFrom(address(seniorTranche), address(this), daiBalance);

        require(dai.balanceOf(address(this) == daiBalance, "spell doesn't own DAI");
    }
}
