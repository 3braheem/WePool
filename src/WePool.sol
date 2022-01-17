// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/**  @title A Fund Pooling project for community investment
     @author 3braheem
**/
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
    mapping(uint256 => mapping(address => Role)) public poolRoleState;
    mapping(uint256 => mapping(address => bool)) public poolMemberState;
    mapping(uint256 => mapping(address => mapping(address => bool)))
        public memberConsent;
    mapping(address => uint256) internal poolGroup;
    uint256 public threshold;

    /** 
        @notice                 Requires that a function be called solely by the admin of a specific pool
        @param _pool            The pool which is being interacted with
        @param _claimant       The address who is trying to access the function
    **/
    modifier onlyAdmin(uint256 _pool, address _claimant) {
        require(poolRoleState[_pool][_claimant] == Role.Administrator);
        _;
    }

    /** 
        @notice                 Requires an address inputted into a function to not be the 0 address
        @param _input           The address that is inputted into the function
    **/
    modifier notNull(address _input) {
        require(_input != address(0));
        _;
    }

    /** 
        @notice                 Requires the specified address to be a member of a specified pool
        @param _pool            The pool which is being interacted with
        @param _input           The address that is inputted 
    **/
    modifier isAMember(uint256 _pool, address _input) {
        require(poolMemberState[_pool][_input] == true);
        _;
    }

    /** 
        @notice                 Requires the inputted index to exist in the system
        @param _poolIndex       The index of a pool in the pools array 
    **/
    modifier poolExists(uint256 _poolIndex) {
        require(_poolIndex < pools.length, "Not an existing pool.");
        _;
    }

    modifier consensusReached(uint256 _accepted, uint256 _length) {
        require(_accepted == _length, "Consensus has not been reached");
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

    function approveAdmin(uint256 _poolIndex, address _admin)
        public
        isAMember(_poolIndex, msg.sender)
        isAMember(_poolIndex, _admin)
        poolExists(_poolIndex)
    {
        memberConsent[_poolIndex][msg.sender][_admin] = true;
    }

    function appointAdmin(uint256 _poolIndex, address _admin)
        public
        isAMember(_poolIndex, msg.sender)
        isAMember(_poolIndex, _admin)
        poolExists(_poolIndex)
    {
        Pool storage pool = pools[_poolIndex];
        address[] memory members = pool.members;
        for (uint256 i = 0; i < members.length; i++) {
            require(
                memberConsent[_poolIndex][members[i]][_admin] = true,
                "Consent has not been reached."
            );
        }
        poolRoleState[_poolIndex][_admin] = Role.Administrator;
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
