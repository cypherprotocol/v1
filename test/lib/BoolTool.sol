// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Bool {
    function toUint256(bool x) internal pure returns (uint256 r) {
        assembly {
            r := x
        }
    }

    function toBool(uint256 x) internal pure returns (string memory r) {
        // x == 0 ? r = "False" : "True";
       if (x == 1) {
            r = "True";
        } else if (x == 0) {
            r = "False";
        } else {}
    }

    function toText(bool x) internal pure returns (string memory r) {
        uint256 inUint = toUint256(x);
        string memory inString = toBool(inUint);
        r = inString;
    }
}