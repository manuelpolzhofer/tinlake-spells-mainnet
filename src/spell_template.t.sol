pragma solidity >=0.5.15 <0.6.0;

import "ds-test/test.sol";
import "./spell_template.sol";


interface AuthLike {
    function wards(address) external returns(uint);
    function rely(address) external;
}

contract Hevm {
    function warp(uint256) public;
    function store(address, bytes32, bytes32) public;
}

contract TinlakeSpellsTest is DSTest {

    Hevm public hevm;
    TinlakeSpell spell;

    address root_;
    address spell_;

    function setUp() public {
        spell = new TinlakeSpell();
        spell_ = address(spell);
        root_ = address(spell.ROOT());
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // cheat: give testContract permissions on root contract by overriding storage
        // storage slot for permissions => keccak256(key, mapslot) (mapslot = 0)
        hevm.store(root_, keccak256(abi.encode(address(this), uint(0))), bytes32(uint(1)));
    }

    function testCast() public {
        // give spell permissions on root contract
        AuthLike(root_).rely(spell_);

        ERC20Like dai = ERC20Like(SeniorTrancheLike(spell.SENIOR_TRANCHE()).currency());
        uint daiBalance = dai.balanceOf(spell.SENIOR_TRANCHE());

        spell.cast();

        // spell should own the DAI after cast
        assertEq(daiBalance, dai.balanceOf(spell_));
    }
}
