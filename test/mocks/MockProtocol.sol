import {CypherProtocol} from "../../src/CypherProtocol.sol";

contract MockProtocol is CypherProtocol {
    constructor(address architect, address registry) CypherProtocol("MockProtocol", architect, registry) {}
}
