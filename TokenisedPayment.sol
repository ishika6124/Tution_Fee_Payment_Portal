// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract TuitionToken {
    string public name = "Tuition Token";
    string public symbol = "TUT";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(uint256 _totalSupply) {
        owner = msg.sender;
        totalSupply = _totalSupply * 10**decimals;
        balances[owner] = totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return allowances[tokenOwner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");
        
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        totalSupply += amount;
        balances[to] += amount;
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
        return true;
    }
}

contract TuitionPayment {
    TuitionToken public tuitionToken;
    uint256 public constant earlyPaymentBonusPercentage = 5; // 5% bonus for early payments

    struct InstallmentPlan {
        address student;
        uint256 totalAmount;
        uint256 remainingAmount;
        uint256 installmentAmount;
        uint256 installmentFrequency; // Frequency in seconds
        uint256 startDate;
        uint256 endDate;
        bool isCompleted;
        uint256 tokensEarned; // Tracks tokens earned for early payments
    }

    mapping(address => InstallmentPlan[]) public studentInstallmentPlans;

    constructor(address _tuitionTokenAddress) {
        tuitionToken = TuitionToken(_tuitionTokenAddress);
    }

    function createInstallmentPlan(uint256 _totalAmount, uint256 _installmentAmount, uint256 _installmentFrequency) public {
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(_installmentAmount > 0, "Installment amount must be greater than zero");
        require(_installmentFrequency > 0, "Installment frequency must be greater than zero");

        InstallmentPlan memory newPlan = InstallmentPlan({
            student: msg.sender,
            totalAmount: _totalAmount,
            remainingAmount: _totalAmount,
            installmentAmount: _installmentAmount,
            installmentFrequency: _installmentFrequency,
            startDate: block.timestamp,
            endDate: block.timestamp + (_installmentFrequency * (_totalAmount + _installmentAmount)),
            isCompleted: false,
            tokensEarned: 0
        });

        studentInstallmentPlans[msg.sender].push(newPlan);
    }

    function makePayment(uint256 paymentAmount, bool payWithTokens) public payable { // Marked as payable to accept ETH
        InstallmentPlan storage plan = studentInstallmentPlans[msg.sender][studentInstallmentPlans[msg.sender].length - 1];
        require(!plan.isCompleted, "Installment plan is already completed");
        require(block.timestamp <= plan.endDate, "Payment is after the installment deadline");

        if (payWithTokens) {
            require(tuitionToken.balanceOf(msg.sender) >= paymentAmount, "Insufficient token balance");
            tuitionToken.transferFrom(msg.sender, address(this), paymentAmount);
        } else {
            require(msg.value >= paymentAmount, "Insufficient ETH sent");
            // Handle excess ETH if needed
            if (msg.value > paymentAmount) {
                payable(msg.sender).transfer(msg.value - paymentAmount); // Refund excess ETH
            }
        }

        // Early payment bonus calculation
        if (block.timestamp < plan.startDate + (plan.installmentFrequency / 2)) { // Payment before half the installment period
            uint256 bonusTokens = (paymentAmount * earlyPaymentBonusPercentage) / 100;
            tuitionToken.mint(msg.sender, bonusTokens); // Mint bonus tokens
            plan.tokensEarned += bonusTokens;
        }

        require(plan.remainingAmount >= paymentAmount, "Payment exceeds remaining amount");

        plan.remainingAmount -= paymentAmount;

        if (plan.remainingAmount == 0) {
            plan.isCompleted = true;
        }
    }

    function getInstallmentPlanStatus(address _student) public view returns (InstallmentPlan[] memory) {
        return studentInstallmentPlans[_student];
    }
}
