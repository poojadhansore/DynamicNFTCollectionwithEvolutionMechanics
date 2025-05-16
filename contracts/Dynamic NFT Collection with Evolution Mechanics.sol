// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Project {
    uint256 private value;

    constructor(uint256 _initialValue) {
        value = _initialValue;
    }

    function setValue(uint256 _value) public {
        value = _value;
    }

    function getValue() public view returns (uint256) {
        return value;
    }
}
