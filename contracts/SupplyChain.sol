pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

contract SupplyChain {

    // Event Logging: Events are emitted for important actions, allowing external listeners (dApps) to track these changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ManagerAdded(address indexed manager);
    event ManagerFired(address indexed manager);
    event EmployeeAdded(address indexed employee);
    event EmployeeFired(address indexed employee);
    event ShipmentAdded(uint shipmentId, string location);
    event ShipmentStateChanged(uint shipmentId, States state, string location);
    event ShipmentCancelled(uint shipmentId);

    // Role-Based Access Control (RBAC)
    address private admin; // Admin address, the owner of the contract
    address private newAdminCandidate; // Candidate address for new admin
    mapping(address => bool) private Managers; // Mapping to track managers
    mapping(address => bool) private Employees; // Mapping to track employees

    // Modifiers for access control to restrict certain functions based on the sender's role
    modifier onlyAdmin {
        require(msg.sender == admin, "You are not the owner!"); // Only the admin can execute
        _;
    }

    modifier onlyManagers {
        require(Managers[msg.sender] || msg.sender == admin, "You are not authorized to perform this action!");
        _;
    }

    modifier onlyEmployees {
        require(Managers[msg.sender] || Employees[msg.sender] || msg.sender == admin, "You are not authorized to perform this action!");
        _;
    }

    // Functions to handle role management (Admin, Manager, Employee)

    // Transfer ownership to a new admin (only callable by current admin)
    function transferOwnership(address newAdmin) public onlyAdmin {
        newAdminCandidate = newAdmin; // Set a candidate for new admin
    }

    // Accept ownership of the contract by the new admin
    function acceptOwnership() public {
        require(msg.sender == newAdminCandidate, "Ownership has not been transferred to you.");
        emit OwnershipTransferred(admin, newAdminCandidate); // Emit event when ownership is transferred
        admin = newAdminCandidate; // Update the admin to the new admin candidate
    }

    // Add a new manager (only callable by admin)
    function addManager(address newManager) public onlyAdmin {
        require(Managers[newManager] == false, "This address is already a manager.");
        Managers[newManager] = true; // Mark address as manager
        emit ManagerAdded(newManager); // Emit event for manager addition
    }

    // Fire an existing manager (only callable by admin)
    function fireManager(address _manager) public onlyAdmin {
        require(Managers[_manager], "This address is not a manager.");
        delete Managers[_manager]; // Remove manager from the mapping
        emit ManagerFired(_manager); // Emit event for manager firing
    }

    // Add a new employee (only callable by managers or admin)
    function addEmployee(address newEmployee) public onlyManagers {
        require(Employees[newEmployee] == false, "This address is already an Employee.");
        Employees[newEmployee] = true; // Mark address as employee
        emit EmployeeAdded(newEmployee); // Emit event for employee addition
    }

    // Fire an existing employee (only callable by managers or admin)
    function fireEmployee(address _employee) public onlyEmployees {
        require(Employees[_employee], "This address is not an employee.");
        delete Employees[_employee]; // Remove employee from the mapping
        emit EmployeeFired(_employee); // Emit event for employee firing
    }

    // Constructor sets the initial admin (deployer of the contract)
    constructor() {
        admin = msg.sender; // Set the contract creator as the initial admin
    }

    // Enum representing the possible states of a shipment
    enum States {
        ShipmentAdded,
        Shipped,
        Dispatched,
        In_Transit,
        Arrived,
        OutForDelivery,
        Delivered,
        Cancelled
    }

    // Struct representing a shipment
    struct shipment {
        uint shipmentId; // Unique identifier for the shipment
        States shipmentState; // Current state of the shipment
        string location; // Current location of the shipment
    }

    // Mapping from shipment ID to the shipment struct
    mapping(uint => shipment) private database;
    uint private lastShipmentId = 1; // To track the next available shipment ID

    // Modifier to ensure that a shipment exists and hasn't been cancelled or delivered
    modifier checkShipment(uint _shipmentId) {
        require(database[_shipmentId].shipmentId != 0, "This shipment does not exist.");
        require(database[_shipmentId].shipmentState != States.Cancelled, "This shipment has been cancelled.");
        require(database[_shipmentId].shipmentState != States.Delivered, "This shipment has been delivered.");
        _;
    }

    // Modifier to ensure the string length is within limits (1-100 characters)
    modifier stringLengthValidation(string memory str) {
        require(bytes(str).length > 0, "String cannot be empty.");
        require(bytes(str).length <= 100, "Cannot set value larger than 100 characters.");
        _;
    }

    // Function to add a new shipment (only callable by managers)
    function addShipment(string memory _location) public onlyManagers stringLengthValidation(_location) returns(uint) {
        shipment memory newShipment;
        newShipment.location = _location;
        newShipment.shipmentState = States.ShipmentAdded; // Initially set to "ShipmentAdded"
        newShipment.shipmentId = lastShipmentId;
        database[lastShipmentId] = newShipment; // Store the new shipment in the database
        emit ShipmentAdded(lastShipmentId, _location); // Emit event for the new shipment
        lastShipmentId++; // Increment the shipment ID for the next shipment
        return newShipment.shipmentId; // Return the new shipment ID
    }

    // Function to change the state of a shipment (with location update)
    function changeShipmentState(uint _shipmentId, States _shipmentState, string memory _location) public onlyEmployees checkShipment(_shipmentId) stringLengthValidation(_location) {
        require(_shipmentState != States.Cancelled, "Only managers can cancel the shipment.");
        database[_shipmentId].shipmentState = _shipmentState; // Update shipment state
        database[_shipmentId].location = _location; // Update shipment location
        emit ShipmentStateChanged(_shipmentId, _shipmentState, _location); // Emit event for the state change
    }

    // Function to change the state of a shipment (without location update)
    function changeShipmentState(uint _shipmentId, States _shipmentState) public onlyEmployees checkShipment(_shipmentId) {
        require(_shipmentState != States.Cancelled, "Only managers can cancel the shipment.");
        database[_shipmentId].shipmentState = _shipmentState; // Update shipment state
        emit ShipmentStateChanged(_shipmentId, _shipmentState, database[_shipmentId].location); // Emit event for the state change
    }

    // Function to cancel a shipment (only callable by managers)
    function cancelShipment(uint _shipmentId) public onlyManagers checkShipment(_shipmentId) {
        emit ShipmentCancelled(_shipmentId); // Emit event for shipment cancellation
        database[_shipmentId].shipmentState = States.Cancelled; // Update shipment state to "Cancelled"
    }

    // Function to check the status of a shipment by its ID
    function checkShipmentStatus(uint _shipmentId) public view returns(uint, States, string memory) {
        require(database[_shipmentId].shipmentId != 0, "This shipment does not exist");
        return (database[_shipmentId].shipmentId, database[_shipmentId].shipmentState, database[_shipmentId].location);
    }
}
