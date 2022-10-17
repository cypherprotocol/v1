import {CypherProtocol} from "../../src/CypherProtocol.sol";

contract MockProtocol is CypherProtocol {
    constructor(address deployer, address registry) CypherProtocol("MockProtocol", deployer, registry) {}
}
