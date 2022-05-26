// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract Spouf is KeeperCompatibleInterface {

    using SafeMath for uint;

    uint public globalBalance;

    event UpdateGoals(Goal[]);
    event UpdateGlobalBalance(uint _globalBalance);

    enum GoalStatus {
        Created,
        Completed,
        Expired,
        Cancelled
    }

    struct Goal {
        string goal;
        uint deadline;
        uint amount;
        GoalStatus status;
    }

    address[] usersCommitted;
    mapping(address => Goal[]) individualGoals;

    struct GoalOOD {
        address addr;
        uint index;
    }

    bool initialized;
    IERC20 USDC;
    IERC20 LINK;

    uint public constant LINK_FEES = 0.2 ether;

    // constructor
    function initialize(address _USDCAddress, address _LINKAddress) public {
        require(!initialized, "Contract instance has already been initialized.");
        initialized = true;
        USDC = IERC20(_USDCAddress);
        LINK = IERC20(_LINKAddress);
    }

    fallback() external payable {
        donate();
    }

    receive() external payable {
        donate();
    }

    function donate() public payable {
        require(
            msg.value >= 1 wei,
            "The user sent an incorrect amount of money."
        );

        // as explicity said, the money donated goes 10% for the Spouf team, and 90% for charities. Here we donate to GiveDirectly, see : https://donate.givedirectly.org/
        // we can't use rational numbers like 0.1, so we dividide by 100 and then multiply by 10 to get 10%
        (bool successTeam, ) = (0xE4E6dC19efd564587C46dCa2ED787e45De17E7E1).call{value: msg.value.div(100).mul(10)}("");
        (bool successCharities, ) = (0x750EF1D7a0b4Ab1c97B7A623D7917CcEb5ea779C).call{value: msg.value.div(100).mul(90)}("");
        require(successTeam && successCharities, "Failed to donate.");
    }

    function setGoal(string memory _goal, uint _deadline, uint _amount) external {
        require(
            _amount >= 1,
            "The user sent an incorrect amount of money."
        );
        require(_deadline > block.timestamp, "Deadline too short.");

        // the user sends 0.2 LINK in case performUpkeep is executed
        bool LINKTransfer = LINK.transferFrom(msg.sender, address(this), LINK_FEES);
        require(LINKTransfer, "LINK transaction failed.");

        bool USDCTransfer = USDC.transferFrom(msg.sender, address(this), _amount);
        require(USDCTransfer, "Transaction failed.");

        // check if the user already has goals in order to not distort usersCommitted value
        if (individualGoals[msg.sender].length == 0) {
            usersCommitted.push(msg.sender);
        }
        
        individualGoals[msg.sender].push(Goal(
            _goal,
            _deadline,
            _amount,
            GoalStatus.Created
        ));

        globalBalance += _amount;
        emit UpdateGlobalBalance(globalBalance);

        emit UpdateGoals(individualGoals[msg.sender]);
    }

    function getGoal() external view returns (Goal[] memory) {
        return individualGoals[msg.sender];
    }

    function deleteGoal(uint _index, bool _completed) external {
        require(_index < individualGoals[msg.sender].length, "Index out of bound.");
        require(
            individualGoals[msg.sender][_index].amount <= USDC.balanceOf(address(this)),
            "Trying to withdraw more money than the contract has."
        );

        // we first give back the money to the user + the LINK fees
        bool LINKTransfer = LINK.transfer(msg.sender, LINK_FEES);
        require(LINKTransfer, "Failed to withdraw LINK from contract.");

        bool USDCTransfer = USDC.transfer(msg.sender, individualGoals[msg.sender][_index].amount);
        require(USDCTransfer, "Failed to withdraw money from contract.");

        if (_completed) {
            individualGoals[msg.sender][_index].status = GoalStatus.Completed;
        } else {
            individualGoals[msg.sender][_index].status = GoalStatus.Cancelled;
        }
        
        // check if the user already has goals in order to not distort usersCommitted's value
        if (individualGoals[msg.sender].length == 0) {
            // gas saving
            address[] memory m_usersCommitted = usersCommitted;
            
            // we loop over the array to pick the searched user to delete
            for (uint j = 0; j < m_usersCommitted.length; j++) {
                if (m_usersCommitted[j] == msg.sender) {
                    // extremely expensive lol, same process as above, see : https://solidity-by-example.org/array/#examples-of-removing-array-element
                    for (uint k = j; k < m_usersCommitted.length - 1; k++) {
                        usersCommitted[k] = usersCommitted[k + 1];
                    }
                    usersCommitted.pop();
                }
            }
        }

        globalBalance -= individualGoals[msg.sender][_index].amount;
        emit UpdateGlobalBalance(globalBalance);

        emit UpdateGoals(individualGoals[msg.sender]);
    }

    // this function is used to check if a goal become out of date. We use ChainLink Keepers to execute that automatically.
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // gas saving
        address[] memory m_usersCommitted = usersCommitted;

        upkeepNeeded = false;
        performData = bytes("");
        
        // we loop over all the users
        for (uint i = 0; i < m_usersCommitted.length; i++) {
            // we loop over every goals of every users
            for (uint j = 0; j < individualGoals[m_usersCommitted[i]].length; j++) {
                if (individualGoals[m_usersCommitted[i]][j].deadline < block.timestamp && individualGoals[m_usersCommitted[i]][j].status == GoalStatus.Created) {
                    upkeepNeeded = true;
                    performData = abi.encode(GoalOOD(m_usersCommitted[i], j));
                    // not necessary but gas efficient because you stop computation as soon as a first condition met
                    return (upkeepNeeded, performData);
                }
            }
        }
        return (upkeepNeeded, performData);
    }

    // this function is executed if a goal is out of date
    function performUpkeep(bytes calldata performData) external override {
        // gas saving
        address[] memory m_usersCommitted = usersCommitted;

        // { we revalidate the upkeep (as adviced in the doc)

        bool upkeepValidated = false;
        // we loop over all the users
        for (uint i = 0; i < m_usersCommitted.length; i++) {
            // we loop over every goals of every users
            for (uint j = 0; j < individualGoals[m_usersCommitted[i]].length; j++) {
                if (individualGoals[m_usersCommitted[i]][j].deadline < block.timestamp && individualGoals[m_usersCommitted[i]][j].status == GoalStatus.Created) {
                    upkeepValidated = true;
                }
            }
        }
        require(upkeepValidated, "There is a problem with Chainlink.");

        // }

        // OOD stands for "out-of-date"
        GoalOOD memory goalOOD = abi.decode(performData, (GoalOOD));
        
        // in the following parts, we have the possibility to reuse other function such as deleteGoal(), why we don't do that is for the gas-efficiency, according to this response I got, it's better to copy paste code https://discord.com/channels/435685690936786944/447826495638077462/954099549142671381

        require(
            individualGoals[goalOOD.addr][goalOOD.index].amount <= USDC.balanceOf(address(this)),
            "Trying to withdraw more money than the contract has."
        );

        // as explicity said, the money lost goes 10% for the Spouf team, and 90% for charities. Here we donate to GiveDirectly, see : https://donate.givedirectly.org/
        // we can't use rational numbers like 0.1, so we dividide by 100 and then multiply by 10 to get 10%
        bool successTeam = USDC.transfer(0xE4E6dC19efd564587C46dCa2ED787e45De17E7E1, individualGoals[goalOOD.addr][goalOOD.index].amount.div(100).mul(10));
        bool successCharities = USDC.transfer(0x750EF1D7a0b4Ab1c97B7A623D7917CcEb5ea779C, individualGoals[goalOOD.addr][goalOOD.index].amount.div(100).mul(90));
        require(successTeam && successCharities, "Failed to withdraw money from contract.");

        individualGoals[goalOOD.addr][goalOOD.index].status = GoalStatus.Expired;

        // check if the user already has goals in order to not distort usersCommitted's value
        if (individualGoals[goalOOD.addr].length == 0) {                
            // we loop over the array to pick the searched user
            for (uint m = 0; m < m_usersCommitted.length; m++) {
                if (m_usersCommitted[m] == goalOOD.addr) {
                    // extremely expensive lol, same process as above, see : https://solidity-by-example.org/array/#examples-of-removing-array-element
                    for (uint n = m; n < m_usersCommitted.length - 1; n++) {
                        usersCommitted[n] = usersCommitted[n + 1];
                    }
                    usersCommitted.pop();
                }
            }
        }

        globalBalance -= individualGoals[goalOOD.addr][goalOOD.index].amount;
        emit UpdateGlobalBalance(globalBalance);

        emit UpdateGoals(individualGoals[msg.sender]);
    }

}
