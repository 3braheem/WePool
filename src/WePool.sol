// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/// @title A Fund Pooling project for community investment
/// @author 3braheem
contract WePool {
    struct Pool {
        address admin;
        address[] members;
        uint256 balance;
    }
    Pool[] public pools;

    enum Role {
        NA,
        Administrator,
        Regular
    }
    mapping(uint256 => mapping(address => Role)) poolRoleState;
    mapping(uint256 => mapping(address => bool)) poolMemberState;
    mapping(address => uint256) poolGroup;

    modifier onlyAdmin(uint256 _pool, address _claimant) {
        require(poolRoleState[_pool][_claimant] == Role.Administrator);
        _;
    }

    modifier notNull(address _input) {
        require(_input != address(0));
        _;
    }

    modifier isAMember(uint256 _pool, address _input) {
        require(poolMemberState[_pool][_input] == true);
        _;
    }

    modifier poolExists(uint256 _poolIndex) {
        require(_poolIndex < pools.length, "Not an existing pool.");
        _;
    }

    event NewPoolCreated(
        address[] indexed members,
        uint256 indexed balance,
        uint256 indexed id
    );

    event DepositMade(
        uint256 indexed id,
        uint256 indexed amount,
        address indexed sender
    );

    event DepositReceived(uint256 indexed amount, address indexed sender);

    receive() external payable {
        emit DepositReceived(msg.value, msg.sender);
    }

    function initGroup(
        address[] memory _members,
        address _admin,
        uint256 _startingBalance
    ) public payable returns (uint256) {
        uint256 poolIndex = pools.length;
        pools.push(
            Pool({admin: _admin, members: _members, balance: _startingBalance})
        );
        for (uint256 i = 0; i < _members.length; i++) {
            poolGroup[_members[i]] = poolIndex;
            poolMemberState[poolIndex][_members[i]] = true;
            poolRoleState[poolIndex][_members[i]] = Role.Regular;
        }
        poolRoleState[poolIndex][_admin] = Role.Administrator;
        emit NewPoolCreated(_members, _startingBalance, poolIndex);
        return poolIndex;
    }

    function deposit(uint256 _poolIndex)
        public
        payable
        isAMember(_poolIndex, msg.sender)
        poolExists(_poolIndex)
    {
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "The call was unsuccessful.");
        emit DepositMade(_poolIndex, msg.value, msg.sender);
    }

    function payout(address _receiver)
        public
        payable
        onlyAdmin(poolGroup[msg.sender], msg.sender)
        notNull(_receiver)
        isAMember(poolGroup[msg.sender], _receiver)
    {
        require(poolGroup[msg.sender] != 0);
        (bool success, ) = _receiver.call{value: msg.value}("");
        require(success, "The call was unsuccessful.");
    }
}
