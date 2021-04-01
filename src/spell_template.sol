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
    function reserve() external returns(address);
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

interface RootLike {
    function lenderDeployer() external returns(address);
}
interface LenderDeployerLike {
    function seniorTranche() external returns(address);
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

    // NS2 Root address
    //address constant public ROOT = 0x53b2d22d07E069a3b132BfeaaD275b10273d381E;

    // consolfreight Root address
    address constant public ROOT = 0xdB3bC9fB1893222d266762e9fF857EB74D75c7D6;

    ERC20Like dai;
    ERC20Like drop;
    TinlakeRootLike root;
    SeniorTrancheLike public seniorTranche;
    address public seniorTranche_;

    ERC20Dummy dummyERC20;

    constructor() public {
        root = TinlakeRootLike(address(ROOT));
        seniorTranche_ = LenderDeployerLike(RootLike(ROOT).lenderDeployer()).seniorTranche();
        seniorTranche = SeniorTrancheLike(seniorTranche_);

        dai = ERC20Like(seniorTranche.currency());
        drop = ERC20Like(seniorTranche.token());
        dummyERC20 = new ERC20Dummy();
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        execute();
    }

    // function signatures of reserve contract
    function deposit(uint amount) external {}
    function payout(uint amount) external {}
    function totalBalanceAvailable() external pure returns (uint) {return 0;}

    function transferDAI(uint daiBalance) internal {
        if(daiBalance > seniorTranche.totalSupply()) {
            uint daiDelta = safeSub(daiBalance, seniorTranche.totalSupply());
            dummyERC20.mint(address(1), daiDelta);
            seniorTranche.depend("currency", address(dummyERC20));
            seniorTranche.supplyOrder(address(1), daiDelta);
            seniorTranche.depend("currency", address(dai));
        }
        require(seniorTranche.totalSupply() >= dai.balanceOf(seniorTranche_), "totalSupply not equal dai balance");
        seniorTranche.closeEpoch();

        // spell needs to act as the reserve
        address reserve = seniorTranche.reserve();
        seniorTranche.depend("reserve", address(this));

        seniorTranche.epochUpdate(10000, 10**27, 0, 1 ether, daiBalance, 0);
        // senior tranche gave approval to spell
        dai.transferFrom(address(seniorTranche), address(this), daiBalance);
        seniorTranche.depend("reserve", reserve);
    }

    function burnDROP(uint dropBalance) internal {
        if(dropBalance > seniorTranche.totalRedeem()) {
            uint dropDelta = safeSub(dropBalance, seniorTranche.totalRedeem());
            dummyERC20.mint(address(2), dropDelta);
            seniorTranche.depend("token", address(dummyERC20));
            seniorTranche.redeemOrder(address(2), dropDelta);
            seniorTranche.depend("token", address(drop));
        }

        require(seniorTranche.totalRedeem() >= drop.balanceOf(seniorTranche_), "totalRedeem not equal drop balance");

        seniorTranche.closeEpoch();

        seniorTranche.epochUpdate(10001, 0, 10**27, 1 ether, 100, dropBalance);
    }

    function migrateERC20Balances() internal {
        // spell needs to be a ward
        root.relyContract(address(seniorTranche), address(this));

        // dai amount we want to move into the spell
        uint daiBalance = dai.balanceOf(seniorTranche_);

        // move DAI from seniorTranche to spell
        transferDAI(daiBalance);
        require(dai.balanceOf(address(this)) == daiBalance, "spell doesn't own the DAI");

        // burn DROP token in seniorTranche
        uint dropBalance = drop.balanceOf(seniorTranche_);
        burnDROP(dropBalance);
        // verify success
        require(drop.balanceOf(seniorTranche_) == 0, "drop not burned");

        // mint DROP token to spell
        root.relyContract(address(drop), address(this));
        drop.mint(address(this), dropBalance);
        // verify success
        require(drop.balanceOf(address(this)) == dropBalance, "drop not burned");

        // make seniorTranche unusable
        seniorTranche.depend("currency", address(0));
        seniorTranche.depend("token", address(0));
    }

    function execute() internal {
        migrateERC20Balances();
    }
}
