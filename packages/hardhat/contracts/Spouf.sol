// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./ops/OpsReady_adapted.sol";
// import {ETH} from "../lib/ops/contracts/vendor/gelato/FGelato.sol";

contract Spouf is Initializable, OwnableUpgradeable, OpsReady {

    using SafeMathUpgradeable for uint;

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

    IERC20Upgradeable USDC;

    uint public FEES;

    address public DEV_ADDRESS;
    address public CHARITY_ADDRESS;

    uint8 public PERCENTAGE_TO_DEV;

    // constructor
    function initialize(address _USDCAddress, address _opsAddress) public initializer {
        __Ownable_init();
        USDC = IERC20Upgradeable(_USDCAddress);
        ops = _opsAddress;
        gelato = IOps(_opsAddress).gelato();
        changeFees(0.01 ether);
        DEV_ADDRESS = 0xE4E6dC19efd564587C46dCa2ED787e45De17E7E1;
        CHARITY_ADDRESS = 0x750EF1D7a0b4Ab1c97B7A623D7917CcEb5ea779C;
        PERCENTAGE_TO_DEV = 10;
    }

    function changePercentageToDev(uint8 _newPercentage) public onlyOwner {
        PERCENTAGE_TO_DEV = _newPercentage;
    }
    
    function changeDevAddress(address _newAddress) public onlyOwner {
        DEV_ADDRESS = _newAddress;
    }

    function changeCharityAddress(address _newAddress) public onlyOwner {
        CHARITY_ADDRESS = _newAddress;
    }

    function changeFees(uint _newFees) public onlyOwner {
        FEES = _newFees;
    }

    function changeUSDCAddress(address _newAddress) public onlyOwner {
        USDC = IERC20Upgradeable(_newAddress);
    }

    function changeOpsAddress(address _newAddress) public onlyOwner {
        ops = _newAddress;
        gelato = IOps(_newAddress).gelato();
    }

    fallback() external payable {
        donate(msg.value);
    }

    receive() external payable {
        donate(msg.value);
    }

    function donate(uint _amount) internal {
        require(
            _amount >= 1 wei,
            "The user sent an incorrect amount of money."
        );

        // as explicity said, the money donated goes 10% for the Spouf team, and 90% for charities. Here we donate to GiveDirectly, see : https://donate.givedirectly.org/
        // we can't use rational numbers like 0.1, so we dividide by 100 and then multiply by 10 to get 10%
        // this percentage can change overtime
        (bool successTeam, ) = payable(DEV_ADDRESS).call{value: _amount.div(100).mul(uint256(PERCENTAGE_TO_DEV))}("");
        (bool successCharities, ) = payable(CHARITY_ADDRESS).call{value: _amount.div(100).mul(100 - uint256(PERCENTAGE_TO_DEV))}("");
        require(successTeam && successCharities, "Failed to donate.");
    }

    function donateToProject() public payable {
        donate(msg.value);
    }

    function setGoal(string calldata _goal, uint _deadline, uint _amount) external payable {
        require(
            _amount >= 1,
            "The user sent an incorrect amount of money."
        );
        require(msg.value >= FEES, "Insufficient fees.");
        require(_deadline > block.timestamp, "Deadline too short.");

        bool USDCTransfer = USDC.transferFrom(msg.sender, address(this), _amount);
        require(USDCTransfer, "Transaction failed.");

        // if the user sent more fees than expected, we donate the rest to charities
        if (msg.value > FEES) {
            donate(msg.value - FEES);
        }

        Goal[] memory m_userGoals = individualGoals[msg.sender];

        // check if the user already has goals in order to not distort usersCommitted value
        if (m_userGoals.length == 0) {
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
        Goal[] memory m_userGoals = individualGoals[msg.sender];

        require(_index < m_userGoals.length, "Index out of bound.");
        require(
            m_userGoals[_index].amount <= USDC.balanceOf(address(this)),
            "Trying to withdraw more money than the contract has."
        );
        require(FEES <= address(this).balance, "Contract hasn't enough funds.");
        require(m_userGoals[_index].status == GoalStatus.Created, "Goal not up-to-date.");

        bool USDCTransfer = USDC.transfer(msg.sender, m_userGoals[_index].amount);
        require(USDCTransfer, "Failed to withdraw money from contract.");

        (bool feesTransfer, ) = payable(msg.sender).call{value: FEES}("");
        require(feesTransfer, "Failed to withdraw money from contract.");

        if (_completed) {
            individualGoals[msg.sender][_index].status = GoalStatus.Completed;
        } else {
            individualGoals[msg.sender][_index].status = GoalStatus.Cancelled;
        }
        
        // check if the user already has goals in order to not distort usersCommitted's value
        if (m_userGoals.length == 0) {
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

        globalBalance -= m_userGoals[_index].amount;
        emit UpdateGlobalBalance(globalBalance);

        emit UpdateGoals(individualGoals[msg.sender]);
    }

    function checker() external view returns (bool canExec, bytes memory execPayload) {
        // gas saving
        address[] memory m_usersCommitted = usersCommitted;

        canExec = false;
        execPayload = bytes("");
        
        // we loop over all the users
        for (uint i = 0; i < m_usersCommitted.length; i++) {
            // we loop over every goals of every users
            Goal[] memory m_userGoals = individualGoals[m_usersCommitted[i]];

            for (uint j = 0; j < m_userGoals.length; j++) {
                if (m_userGoals[j].deadline < block.timestamp && m_userGoals[j].status == GoalStatus.Created) {
                    canExec = true;
                    execPayload = abi.encodeWithSelector(this.executeGoalOutOfDate.selector, address(m_usersCommitted[i]), uint(j));
                    // not necessary but gas efficient because you stop computation as soon as a first condition met
                    return (canExec, execPayload);
                }
            }
        }
        return (canExec, execPayload);
    }

    // this function is executed if a goal is out of date
    // OOD stands for "out-of-date"
    function executeGoalOutOfDate(address OODUserAddress, uint OODIndex) public onlyOps {
        // gas saving
        address[] memory m_usersCommitted = usersCommitted;

        Goal[] memory m_indivGoals = individualGoals[OODUserAddress];

        require(m_indivGoals[OODIndex].deadline < block.timestamp, "Goal hasn't expired yet.");
        require(m_indivGoals[OODIndex].status == GoalStatus.Created, "Invalid goal.");
        
        // in the following parts, we have the possibility to reuse other function such as deleteGoal(), why we don't do that is for the gas-efficiency, according to this response I got, it's better to copy paste code https://discord.com/channels/435685690936786944/447826495638077462/954099549142671381

        require(
            m_indivGoals[OODIndex].amount <= USDC.balanceOf(address(this)),
            "Trying to withdraw more money than the contract has."
        );

        // as explicity said, the money lost goes 10% for the Spouf team, and 90% for charities. Here we donate to GiveDirectly, see : https://donate.givedirectly.org/
        // we can't use rational numbers like 0.1, so we dividide by 100 and then multiply by 10 to get 10%
        bool successTeam = USDC.transfer(DEV_ADDRESS, m_indivGoals[OODIndex].amount.div(100).mul(uint256(PERCENTAGE_TO_DEV)));
        bool successCharities = USDC.transfer(CHARITY_ADDRESS, m_indivGoals[OODIndex].amount.div(100).mul(100 - uint256(PERCENTAGE_TO_DEV)));
        require(successTeam && successCharities, "Failed to withdraw money from contract.");

        // we pay for the execution thanks to Gelato
        uint fee;
        address feeToken;

        (fee, feeToken) = IOps(ops).getFeeDetails();
        _transfer(fee, feeToken);

        // we give back the fees surplus to the user
        if (FEES > fee) {
            (bool transferFees, ) = payable(OODUserAddress).call{value: FEES - fee}("");
            require(transferFees, "Failed to give back fees.");
        }

        individualGoals[OODUserAddress][OODIndex].status = GoalStatus.Expired;

        // check if the user already has goals in order to not distort usersCommitted's value
        if (m_indivGoals.length == 0) {                
            // we loop over the array to pick the searched user
            for (uint m = 0; m < m_usersCommitted.length; m++) {
                if (m_usersCommitted[m] == OODUserAddress) {
                    // extremely expensive lol, same process as above, see : https://solidity-by-example.org/array/#examples-of-removing-array-element
                    for (uint n = m; n < m_usersCommitted.length - 1; n++) {
                        usersCommitted[n] = usersCommitted[n + 1];
                    }
                    usersCommitted.pop();
                }
            }
        }

        globalBalance -= m_indivGoals[OODIndex].amount;
        emit UpdateGlobalBalance(globalBalance);

        emit UpdateGoals(individualGoals[OODUserAddress]);
    }

}
