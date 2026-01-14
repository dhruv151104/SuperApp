// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ProductTraceability {
    // Role in the supply chain for a particular hop
    enum Role {
        Manufacturer,
        Retailer
    }

    // Lifecycle status of a product
    enum Status {
        Active,
        Completed
    }

    // One step in the product journey
    struct Hop {
        Role role;          // Manufacturer or Retailer
        address actor;      // Address of the manufacturer/retailer
        string location;    // Location string captured from the app
        uint256 timestamp;  // When this hop was recorded
    }

    // Product with complete history
    struct Product {
        string productId;
        address manufacturer;
        Hop[] history; // First hop is manufacturer, then one or more retailers
        Status status;
        bool exists;
    }

    mapping(string => Product) private products;

    // Contract owner (e.g. admin backend) who can manage allowlists
    address public owner;

    // Allowlisted actors
    mapping(address => bool) public isManufacturer;
    mapping(address => bool) public isRetailer;

    // Track if a retailer has already added a hop for a particular product
    mapping(string => mapping(address => bool)) private retailerHasHop;

    event ProductCreated(
        string productId,
        address manufacturer,
        string location,
        uint256 timestamp
    );

    event HopAdded(
        string productId,
        Role role,
        address actor,
        string location,
        uint256 timestamp
    );

    event ProductCompleted(
        string productId,
        address completedBy,
        uint256 timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Add or remove an address from the manufacturer allowlist
    function setManufacturer(address account, bool allowed) external onlyOwner {
        isManufacturer[account] = allowed;
    }

    /// @notice Add or remove an address from the retailer allowlist
    function setRetailer(address account, bool allowed) external onlyOwner {
        isRetailer[account] = allowed;
    }

    /// @notice Transfer contract ownership to a new address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Renounce ownership so no further owner-only actions are possible
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /// @notice Manufacturer creates a new product when it is manufactured
    /// @param productId Unique ID encoded in the QR code
    /// @param manufacturerLocation Location captured from mobile app
    function createProduct(
        string calldata productId,
        string calldata manufacturerLocation
    ) external {
        require(!products[productId].exists, "Product already exists");
        require(isManufacturer[msg.sender], "Not allowed manufacturer");

        Product storage p = products[productId];
        p.productId = productId;
        p.manufacturer = msg.sender;
        p.status = Status.Active;
        p.exists = true;

        // First hop: manufacturer
        p.history.push(
            Hop({
                role: Role.Manufacturer,
                actor: msg.sender,
                location: manufacturerLocation,
                timestamp: block.timestamp
            })
        );

        emit ProductCreated(
            productId,
            msg.sender,
            manufacturerLocation,
            block.timestamp
        );
    }

    /// @notice Retailer scans QR to append their info to the history
    /// @param productId Product ID from QR
    /// @param retailerLocation Retailer location captured from app
    function addRetailerHop(
        string calldata productId,
        string calldata retailerLocation
    ) external {
        Product storage p = products[productId];
        require(p.exists, "Product does not exist");
        require(p.status == Status.Active, "Product not active");
        require(isRetailer[msg.sender], "Not allowed retailer");
        require(
            !retailerHasHop[productId][msg.sender],
            "Retailer already added for product"
        );

        // Append new retailer hop
        p.history.push(
            Hop({
                role: Role.Retailer,
                actor: msg.sender,
                location: retailerLocation,
                timestamp: block.timestamp
            })
        );

        retailerHasHop[productId][msg.sender] = true;

        emit HopAdded(
            productId,
            Role.Retailer,
            msg.sender,
            retailerLocation,
            block.timestamp
        );
    }

    /// @notice Mark a product as completed/sold; no further hops can be added
    /// @dev Can be called by the manufacturer or the contract owner
    function completeProduct(string calldata productId) external {
        Product storage p = products[productId];
        require(p.exists, "Product does not exist");
        require(p.status == Status.Active, "Product already completed");
        require(
            msg.sender == p.manufacturer || msg.sender == owner,
            "Not authorized to complete"
        );

        p.status = Status.Completed;

        emit ProductCompleted(productId, msg.sender, block.timestamp);
    }

    /// @notice Get full on-chain info for a product
    /// @return productId ID string
    /// @return manufacturer Manufacturer address
    /// @return history Full array of hops (manufacturer + all retailers)
    function getProduct(
        string calldata productId
    )
        external
        view
        returns (string memory, address, Hop[] memory)
    {
        Product storage p = products[productId];
        require(p.exists, "Product does not exist");

        return (p.productId, p.manufacturer, p.history);
    }
}
