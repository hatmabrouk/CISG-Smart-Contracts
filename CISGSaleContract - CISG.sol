// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract CISGSaleContract {
    address public seller;
    address public buyer;
    uint256 public totalPrice;
    uint256 public unitPrice;
    uint256 public quantity;
    string public goodsDescription;
    string public qualityStandard;
    uint256 public tolerance;
    string public incoterms;
    uint256 public deliveryDeadline;
    uint256 public inspectionPeriod = 5 days;
    bool public goodsDelivered;
    bool public goodsAccepted;
    uint256 public penaltyRate = 5; // 0.5% per day penalty
    uint256 public forceMajeureExpiration;
    bool public forceMajeureActive;
    uint256 public interestRate = 5; // 5% annual interest
    
    // Legal & Arbitration Details
    string public arbitrationMethod = "UNCITRAL arbitration";
    uint8 public arbitrators = 3;
    string public arbitrationLocation = "Geneva";
    string public arbitrationLanguage = "English";
    
    // Letter of Credit Details
    string public letterOfCreditType = "Irrevocable Letter of Credit";
    string public issuingBank = "Issued by BNP Paribas, France";
    
    // Retention of Title
    bool public paymentCompleted;
    
    enum ContractState { Created, InProgress, Completed, Disputed, Terminated }
    ContractState public state;

    struct Dispute {
        address raisedBy;
        string reason;
        uint256 timestamp;
        bool resolved;
    }

    Dispute public contractDispute;
    mapping(address => string[]) public notifications;
    
    modifier onlySeller() {
        require(msg.sender == seller, "Only the seller can perform this action.");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only the buyer can perform this action.");
        _;
    }

    modifier inState(ContractState _state) {
        require(state == _state, "Invalid contract state.");
        _;
    }

    event PaymentVerified(address indexed buyer);
    event GoodsShipped(address indexed seller, uint256 timestamp);
    event GoodsAccepted(address indexed buyer, uint256 timestamp);
    event LateDeliveryPenaltyApplied(uint256 penaltyAmount);
    event ForceMajeureInvoked(uint256 timestamp);
    event DisputeRaised(address indexed party, string reason);
    event ContractTerminated(string reason);
    event NotificationSent(address indexed recipient, string message);
    
    constructor(
        address _buyer,
        uint256 _totalPrice,
        uint256 _unitPrice,
        uint256 _quantity,
        string memory _goodsDescription,
        string memory _qualityStandard,
        uint256 _tolerance,
        uint256 _deliveryDeadline
    ) {
        seller = msg.sender;
        buyer = _buyer;
        totalPrice = _totalPrice;
        unitPrice = _unitPrice;
        quantity = _quantity;
        goodsDescription = _goodsDescription;
        qualityStandard = _qualityStandard;
        tolerance = _tolerance;
        incoterms = "FOB - London Port";
        deliveryDeadline = block.timestamp + _deliveryDeadline;
        state = ContractState.Created;
    }

    function verifyLetterOfCredit(bool approved) external onlyBuyer inState(ContractState.Created) {
        require(approved, "Letter of Credit must be verified.");
        paymentCompleted = true;
        state = ContractState.InProgress;
        emit PaymentVerified(msg.sender);
    }

    function markGoodsShipped() external onlySeller inState(ContractState.InProgress) {
        require(paymentCompleted, "Payment verification required.");
        require(block.timestamp <= deliveryDeadline, "Delivery deadline passed.");
        goodsDelivered = true;
        emit GoodsShipped(msg.sender, block.timestamp);
    }

    function acceptGoods() external onlyBuyer inState(ContractState.InProgress) {
        require(goodsDelivered, "Goods have not been shipped.");
        require(block.timestamp <= deliveryDeadline + inspectionPeriod, "Inspection period expired.");
        goodsAccepted = true;
        state = ContractState.Completed;
        emit GoodsAccepted(msg.sender, block.timestamp);
    }

    function applyLateDeliveryPenalty() external onlyBuyer inState(ContractState.InProgress) {
        require(block.timestamp > deliveryDeadline, "Delivery is not late yet.");
        uint256 lateDays = (block.timestamp - deliveryDeadline) / 1 days;
        uint256 penalty = (totalPrice * penaltyRate * lateDays) / 1000; // 0.5% per day
        uint256 interest = (totalPrice * interestRate * lateDays) / (100 * 365); // Interest on late payment
        emit LateDeliveryPenaltyApplied(penalty + interest);
    }

    function raiseDispute(string calldata _reason) external {
        require(msg.sender == seller || msg.sender == buyer, "Only parties can raise a dispute.");
        require(state != ContractState.Completed, "Contract is already completed.");
        contractDispute = Dispute(msg.sender, _reason, block.timestamp, false);
        state = ContractState.Disputed;
        emit DisputeRaised(msg.sender, _reason);
    }

    function invokeForceMajeure(uint256 duration) external {
        require(msg.sender == seller || msg.sender == buyer, "Only parties can invoke force majeure.");
        forceMajeureActive = true;
        forceMajeureExpiration = block.timestamp + duration;
        emit ForceMajeureInvoked(block.timestamp);
    }

    function terminateContract(string calldata reason) external {
        require(msg.sender == seller || msg.sender == buyer, "Only parties can terminate the contract.");
        state = ContractState.Terminated;
        emit ContractTerminated(reason);
    }

    function sendNotification(address recipient, string calldata message) external {
        require(msg.sender == seller || msg.sender == buyer, "Only contract parties can send notifications.");
        notifications[recipient].push(message);
        emit NotificationSent(recipient, message);
    }
}
