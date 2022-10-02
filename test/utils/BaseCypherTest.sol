import "forge-std/Test.sol";
import {CypherRegistry} from "../../src/CypherRegistry.sol";
import {CypherEscrow} from "../../src/CypherEscrow.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockProtocol} from "../mocks/MockProtocol.sol";

contract BaseCypherTest is Test {
    uint256 constant MAX_INT = ~uint256(0);
    uint256 constant THRESHOLD = 50;
    uint256 constant EXPIRY_DURATION = 1 days;

    CypherEscrow escrow;
    CypherRegistry registry;

    address payable internal alice = payable(address(0xBEEF));
    address payable internal bob = payable(address(0xBABE));
    address payable internal carol = payable(address(0xCAFE));
    address payable internal dave = payable(address(0xDEAD));

    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC20 internal token3;

    MockProtocol internal protocol;

    MockERC20[] erc20s;
    address[] oracles;

    function setUp() public virtual {
        vm.label(alice, "alice: non-cypher user");
        vm.label(bob, "bob: cypher user");
        vm.label(carol, "carol: oracle");
        vm.label(dave, "dave: architect");
        vm.label(address(this), "testContract");

        _deployTestContracts();

        erc20s = [token1, token2, token3];
        oracles = [carol];

        _deployContracts();

        allocateTokensAndApprovals(alice, uint128(MAX_INT));
        allocateTokensAndApprovals(bob, uint128(MAX_INT));
        allocateTokensAndApprovals(carol, uint128(MAX_INT));
        allocateTokensAndApprovals(dave, uint128(MAX_INT));
    }

    function _deployContracts() public {
        registry = new CypherRegistry();
        protocol = new MockProtocol(dave, address(registry));

        vm.prank(dave);
        escrow = CypherEscrow(
            registry.createEscrow(address(protocol), address(token1), THRESHOLD, EXPIRY_DURATION, oracles)
        );
    }

    function _grantApprovals(address user, address spender) public {
        vm.startPrank(user);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(spender, MAX_INT);
        }
        vm.stopPrank();
    }

    function _deployTestContracts() internal {
        token1 = new MockERC20();
        token2 = new MockERC20();
        token3 = new MockERC20();

        vm.label(address(token1), "token1");
        vm.label(address(token2), "token2");
        vm.label(address(token3), "token3");

        emit log(unicode"✅ Deployed test token contracts");
    }

    function allocateTokensAndApprovals(address _to, uint128 _amount) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].mint(_to, _amount);
        }
        emit log_named_address(unicode"✅ Allocated tokens to", _to);
    }

    function _assignEscrowAsArchitect(address _contract) internal {
        vm.startPrank(dave);
        registry.attachEscrow(address(escrow), _contract);
        vm.stopPrank();

        emit log_named_address(unicode"✅ Assigned escrow to", _contract);
    }
}
