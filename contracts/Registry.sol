pragma solidity 0.5.1;

/**
 * @title Registry
 * @author Rob Hitchens
 * @notice Trustless upgradable contract implementation registry.
 */

import "./HitchensUnorderedAddressSet.sol";
import "./Upgradable.sol";
import "./Ownable.sol";

interface RegistryInterface {
    function componentUid() external view returns(bytes32);
    function addImplementation(address implementationAddress) external;
    function recallImplementation(address implementationAddress) external;
    function setDefaultImplementation(address implementationAddress) external;
    function setMyImplementation(address implementationAddress) external;
    function userImplementation(address user) external view returns(address);
    function myImplementation() external view returns(address);
    function isImplementation(address implementationAddress) external view returns(bool);
    function implementationCount() external view returns(uint);
    function implementationAtIndex(uint index) external view returns(address);
}

contract Registry is RegistryInterface, Ownable {
    
    using HitchensUnorderedAddressSetLib for HitchensUnorderedAddressSetLib.Set;
    HitchensUnorderedAddressSetLib.Set validImplementations;
    
    bool public OPT_IN;
    
    address defaultImplementation;
    address constant UNDEFINED = address(0);
    bytes32 COMPONENT_UID;
    
    mapping(address => address) userImplementationChoices;
    
    event LogNewRegistry(address sender, address registry, bool optInPolicy);
    event LogNewImplementation(address sender, address implementation);
    event LogRecalledImplementation(address sender, address implementation);
    event LogNewDefaultImplementation(address sender, address implementation);
    event LogUserImplementation(address sender, address implementation);
    
    /**
     * @notice Ensures a unique identifier for the component this registry is concerned with. 
     * @param optIn The permanent registry policy that governs default user upgrade policy. 
     *        True means users accept all default implementations unless they explicitly lock in a preferred version. 
     *        False means each user must explicitly lock in a version and default implementations have no effect.
     */
    constructor(bool optIn) public {
        OPT_IN = optIn;
        COMPONENT_UID = keccak256(abi.encodePacked(msg.sender));
        emit LogNewRegistry(msg.sender, address(this), optIn);
    }
    
    /**
     * @return bytes32 The componentUid this registry accepts.
     */
    function componentUid() public view returns(bytes32) {
        return COMPONENT_UID;
    }
    
    /**
     * @param implementationAddress Address of a compatible implementation contract. 
     * @notice The componentUid() function in the implementationAddress must return a matching componentUid. This helps prevent deployment errors. 
     */
    function addImplementation(address implementationAddress) public onlyOwner {
        UpgradableInterface u = UpgradableInterface(implementationAddress);
        require(u.componentUid() == COMPONENT_UID, "Implementation.componentUid doesn't match this registry's componentUid.");
        validImplementations.insert(implementationAddress);
        emit LogNewImplementation(msg.sender, implementationAddress);
    }
    
    /**
     * @param implementationAddress The address of an implementation contract to recall. 
     * @notice onlyOwner. Cannot recall the default implementation. 
     */
    function recallImplementation(address implementationAddress) public onlyOwner {
        require(implementationAddress != defaultImplementation, "Cannot recall default implementation.");
        validImplementations.remove(implementationAddress);
        emit LogRecalledImplementation(msg.sender, implementationAddress);
    }
    
    /**
     * @param implementationAddress Set the default implementation. 
     * @notice onlyOwner. The default implementation address must be registered. 
     */
    function setDefaultImplementation(address implementationAddress) public onlyOwner {
        require(isImplementation(implementationAddress), "implementationAddress is not registered.");
        defaultImplementation = implementationAddress;
        emit LogNewDefaultImplementation(msg.sender, implementationAddress);
    }
    
    /**
     * @param implementationAddress User's preferred implementation. 
     * @notice Overrides the default implementation unless the user's preferred implementation was recalled. 
     * @notice Set to 0x0 to use the present and future default implementation set by the registry owner.
     */
    function setMyImplementation(address implementationAddress) public {
        if(implementationAddress != UNDEFINED) require(isImplementation(implementationAddress), "implementationAddress is not registered.");
        userImplementationChoices[msg.sender] = implementationAddress;
        emit LogUserImplementation(msg.sender, implementationAddress);
    }
    
    /**
     * @notice Returns the implementation contract to use per user choices, opt-in/opt-out registry policy and the default implementation.
     * @param user The user to inspect.
     * @return address The user's effective implementation address.
     */
    function userImplementation(address user) public view returns(address) {
        address userImpl = userImplementationChoices[user];
        if(OPT_IN) {
            if(!validImplementations.exists(userImpl)) return defaultImplementation;
            return userImpl;
        } else {
            require(userImpl != address(0), "User must setMyImplementation() first.");
            require(validImplementations.exists(userImpl), "User's selected implementation is recalled. User must setMyImplementation().");
            return userImpl;
        }
    }
    
    /**
     * @return address msg.sender's preferred implementation address.
     */
    function myImplementation() public view returns(address) {
        return userImplementation(msg.sender);
    }
    
    /**
     * @param implementationAddress The address to check. 
     * @return bool True if the implementation is a registered implementation.
     */
    function isImplementation(address implementationAddress) public view returns(bool) {
        return validImplementations.exists(implementationAddress);
    }
    
    /**
     * @return uint The count of implementation contracts registered. 
     */
    function implementationCount() public view returns(uint) {
        return validImplementations.count();
    }
    
    /**
     * @param index The row number to inspect. 
     * @return address The address of an implementtion address.
     */
    function implementationAtIndex(uint index) public view returns(address) {
        return validImplementations.keyAtIndex(index);
    }
}
