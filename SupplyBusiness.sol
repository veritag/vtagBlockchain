pragma solidity ^0.4.19;

/**
 * @title Ownable contract
 */
contract Ownable {
    address public owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title SupplyBusiness contract
 */
contract SupplyBusiness is Ownable
{
    /**
     * Business struct
     */
    struct Business {
        uint _index;
        string _name;
        address _address;
    }
    
    /**
     * Business router mapping: bizName => Business
     */
    mapping(bytes32 => Business) private business;
    
    /**
     * Business name array
     */
    bytes32[] private businessIndice;
    
    /**
     * check if business exists in db
     */
    function isExist(string name) public constant returns (bool)
    {
        if(businessIndice.length == 0)
            return false;
            
        bytes32 _name = stringToBytes32(name);
            
        return (businessIndice[business[_name]._index] == _name);
    }
    
    /**
     * add new business to db
     */
    event AddBusiness(string _name, address indexed _address);
    function addBusiness(string name, address contractAddress) public returns (bool)
    {
        require(isExist(name) == false);
        
        bytes32 _name = stringToBytes32(name);
        
        businessIndice.push(_name);
        
        business[_name]._index = businessIndice.length - 1;
        business[_name]._name = name;
        business[_name]._address = contractAddress;
        
        emit AddBusiness(name, contractAddress);
        return true;
    }
    
    /**
     * remove existing business from db
     */
    function removeBusiness(string name) onlyOwner public returns (bool)
    {
        require(isExist(name) == true);
        
        bytes32 _name = stringToBytes32(name);
        
        uint rowToDelete = business[_name]._index;
        bytes32 keyToMove = businessIndice[businessIndice.length-1];
        businessIndice[rowToDelete] = keyToMove;
        business[keyToMove]._index = rowToDelete; 
        businessIndice.length = businessIndice.length - 1;
    
        return true;
    }
    
    /**
     * get existing business from db
     */
    event GetBusiness(string _name, address indexed _address);
    function getBusiness(string name) onlyOwner public constant returns (address contractAddress)
    {
        require(isExist(name) == true);
        
        bytes32 _name = stringToBytes32(name);
        
        emit GetBusiness(name, business[_name]._address);
        
        return business[_name]._address;
    }
    
    /**
     * edit existing business in db
     */
    function editBusiness(string name, address contractAddress) onlyOwner public returns (bool)
    {
        require(isExist(name) == true);
        
        bytes32 _name = stringToBytes32(name);
        
        business[_name]._address = contractAddress;
        
        return true;
    }
    
    /**
     * get all count of businesses from db
     */
    function getBusinessCount() public constant returns (uint count)
    {
        return businessIndice.length;
    }
    
    /**
     * convert string to bytes32
     */
    function stringToBytes32(string memory source) internal view returns (bytes32 result) 
    {
        if (isEmptyString(source)) return 0x0;

        assembly {
            result := mload(add(source, 32))
        }
    }
    
    /**
     * check if string is empty
     */
    function isEmptyString(string str) internal view returns (bool)
    {
        bytes memory tempEmptyStringTest = bytes(str);
        if (tempEmptyStringTest.length == 0) {
            return true;
        }
        return false;
    }
}

/**
 * @title ProductTrack contract
 */
contract ProductTrack is Ownable
{
    /**
     * Product info struct
     */
    struct Product 
    {
        uint _index;
        string _labelNo;
        string _id;
        string _name;
        string _shipmentId;
        string _countryOrigin;
        string _expireDate;
        string _sealTagLogDate;
        
        bytes32 _txHash;
        uint _timestamp;
    }
    
    /**
     * Product trackings struct
     */
    struct ProductTracking 
    {
        uint _index;
        string _labelNo;
        mapping (bytes32 => Product) _products;                 // map: trackingSeq => Product
        bytes32[] _sequences;
    }
    
    /**
     * Transaction hash struct
     */
    struct TxHash
    {
        uint _index;
        bytes32 _labelNo;
        bytes32 _sequence;
    }
    
    /**
     * Business name
     */
    string public BUSINESSNAME;
    
    /**
     * 1st mapping is indexed by labelNo normally, 2nd is mapping indexed by states(001, 002, 003, etc): labelNo => ProductTracking
     */
    mapping (bytes32 => ProductTracking) private productDB;
    bytes32[] private labels;
    
    /**
     * 2nd mapping indexed by txHash based on labelNo map: txHash => (labelNo, trackingSeq)
     */
    mapping (bytes32 => TxHash) hashMap;
    bytes32[] hashs;
    
    /**
     * contract construct with business name
     */
    function ProductTrack(string bizName, address supply) public
    {
        BUSINESSNAME = bizName;
        SupplyBusiness supBiz = SupplyBusiness(supply);
        supBiz.addBusiness(bizName, address(this));
    }
    
    /**
     * check if product exists in db
     */
    function isExist(string labelNo) public constant returns (bool)
    {
        if(labels.length == 0)
            return false;
            
        bytes32 _labelNo = stringToBytes32(labelNo);
            
        return (labels[productDB[_labelNo]._index] == _labelNo);
    }
    
    /**
     * add new product in db
     */
    event UploadProduct(string labelNo, string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate);
    function uploadProduct(string labelNo, string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate) 
        public returns (bool)
    {
        require(isEmptyString(labelNo) == false && isEmptyString(id) == false);
        
        tracking(labelNo, "001", id, name, shipmentId, countryOrigin, expireDate, sealTagLogDate);
        
        emit UploadProduct(labelNo, id, name, shipmentId, countryOrigin, expireDate, sealTagLogDate);
        return true;
    }
    
    /**
     * update transaction hash with specific txHash for point 1, 2, 3, ...
     */
    event UpdateTxHash(string labelNo, string trackingSeq, bytes32 txHash, uint timestamp);
    function updateTxHash(string labelNo, string trackingSeq, bytes32 txHash) public returns (bool)
    {
        require(isExist(labelNo) == true);
        
        bytes32 _labelNo = stringToBytes32(labelNo);
        bytes32 _trackingSeq = stringToBytes32(trackingSeq);
        
        require(productDB[_labelNo]._sequences[productDB[_labelNo]._products[_trackingSeq]._index] == _trackingSeq);
        
        productDB[_labelNo]._products[_trackingSeq]._txHash = txHash;
        
        // construct txHash indexing db
        if(hashs.length == 0 || hashs[hashMap[txHash]._index] != txHash)
        {
            hashs.push(txHash);
            
            hashMap[txHash]._index = hashs.length - 1;
            hashMap[txHash]._labelNo = _labelNo;
            hashMap[txHash]._sequence = _trackingSeq;
        }
        else
        {
            hashMap[txHash]._labelNo = _labelNo;
            hashMap[txHash]._sequence = _trackingSeq;
        }
        
        emit UpdateTxHash(labelNo, trackingSeq, txHash, productDB[_labelNo]._products[_trackingSeq]._timestamp);
        return true;
    }
    
    /**
     * track product status for every points
     */
    event Tracking(string labelNo, string trackingSeq, string id, string expireDate, string sealTagLogDate, uint timestamp);
    function tracking(string labelNo, string trackingSeq, string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate) 
        public returns (bool)
    {
        bytes32 _labelNo = stringToBytes32(labelNo);
        bytes32 _trackingSeq = stringToBytes32(trackingSeq);
        
        if(isEqual(trackingSeq, "001"))
        {
            require(isExist(labelNo) == false);
        
            labels.push(_labelNo);
            
            productDB[_labelNo]._index = labels.length - 1;
            productDB[_labelNo]._labelNo = labelNo;
            
            // add product info at Seq 001
            require(productDB[_labelNo]._sequences.length == 0 || productDB[_labelNo]._sequences[productDB[_labelNo]._products[_trackingSeq]._index] != _trackingSeq);
            
            productDB[_labelNo]._sequences.push(_trackingSeq);
            
            productDB[_labelNo]._products[_trackingSeq]._index = productDB[_labelNo]._sequences.length - 1;
            productDB[_labelNo]._products[_trackingSeq]._labelNo = labelNo;
            productDB[_labelNo]._products[_trackingSeq]._id = id;
            productDB[_labelNo]._products[_trackingSeq]._name = name;
            productDB[_labelNo]._products[_trackingSeq]._shipmentId = shipmentId;
            productDB[_labelNo]._products[_trackingSeq]._countryOrigin = countryOrigin;
            productDB[_labelNo]._products[_trackingSeq]._expireDate = expireDate;
            productDB[_labelNo]._products[_trackingSeq]._sealTagLogDate = sealTagLogDate;
            productDB[_labelNo]._products[_trackingSeq]._timestamp = block.timestamp;
            
            emit Tracking(labelNo, trackingSeq, id, expireDate, sealTagLogDate, block.timestamp);
            return true;
        }
        else
        {
            require(isExist(labelNo) == true);
            
            // if not exist, we will add product info at Seq 002, 003, etc
            if(productDB[_labelNo]._sequences[productDB[_labelNo]._products[_trackingSeq]._index] != _trackingSeq)
            {
                productDB[_labelNo]._sequences.push(_trackingSeq);
                
                productDB[_labelNo]._products[_trackingSeq]._index = productDB[_labelNo]._sequences.length - 1;
                productDB[_labelNo]._products[_trackingSeq]._labelNo = labelNo;
                productDB[_labelNo]._products[_trackingSeq]._id = id;
                productDB[_labelNo]._products[_trackingSeq]._name = name;
                productDB[_labelNo]._products[_trackingSeq]._shipmentId = shipmentId;
                productDB[_labelNo]._products[_trackingSeq]._countryOrigin = countryOrigin;
                productDB[_labelNo]._products[_trackingSeq]._expireDate = expireDate;
                productDB[_labelNo]._products[_trackingSeq]._sealTagLogDate = sealTagLogDate;
                productDB[_labelNo]._products[_trackingSeq]._timestamp = block.timestamp;
                
                emit Tracking(labelNo, trackingSeq, id, expireDate, sealTagLogDate, block.timestamp);
                return true;
            }
            else 
            {
                productDB[_labelNo]._products[_trackingSeq]._labelNo = labelNo;
                productDB[_labelNo]._products[_trackingSeq]._id = id;
                productDB[_labelNo]._products[_trackingSeq]._name = name;
                productDB[_labelNo]._products[_trackingSeq]._shipmentId = shipmentId;
                productDB[_labelNo]._products[_trackingSeq]._countryOrigin = countryOrigin;
                productDB[_labelNo]._products[_trackingSeq]._expireDate = expireDate;
                productDB[_labelNo]._products[_trackingSeq]._sealTagLogDate = sealTagLogDate;
                productDB[_labelNo]._products[_trackingSeq]._timestamp = block.timestamp;
                
                emit Tracking(labelNo, trackingSeq, id, expireDate, sealTagLogDate, block.timestamp);
                return true;
            }
        }
    }
    
    /**
     * get prodcut tracking history by labelNo
     */
    bytes32[] _ids;
    bytes32[] _names;
    bytes32[] _shipmentIds;
    bytes32[] _countryOrigins;
    bytes32[] _expireDates;
    bytes32[] _sealTagLogDates;
    bytes32[] _txHashs;
    uint[] _timestamps;
    
    event GetTransactionHistory(bytes32[] ids, bytes32[] shipmentIds, bytes32[] countryOrigins, bytes32[] expireDates, bytes32[] sealTagLogDates, bytes32[] txHashs,
        uint[] timestamps);
    function getTransactionHistory(string labelNo) public constant returns (bytes32[], bytes32[], bytes32[], bytes32[], bytes32[], bytes32[], uint[])
    {
        require(isExist(labelNo) == true);
        
        bytes32 __labelNo = stringToBytes32(labelNo);
        
        uint len = productDB[__labelNo]._sequences.length;
        
        for (uint i=0; i<len; i++)
        {
            bytes32 id = productDB[__labelNo]._sequences[i];
            
            Product memory pt = productDB[__labelNo]._products[id];
            
            _ids.push(stringToBytes32(pt._id));
            _names.push(stringToBytes32(pt._name));                 // ignored since stack deeper issue
            _shipmentIds.push(stringToBytes32(pt._shipmentId));
            _countryOrigins.push(stringToBytes32(pt._countryOrigin));
            _expireDates.push(stringToBytes32(pt._expireDate));
            _sealTagLogDates.push(stringToBytes32(pt._sealTagLogDate));
            _txHashs.push(pt._txHash);
            _timestamps.push(pt._timestamp);
        }
        
        emit GetTransactionHistory(_ids, _shipmentIds, _countryOrigins, _expireDates, _sealTagLogDates, _txHashs, _timestamps);
        return(_ids, _shipmentIds, _countryOrigins, _expireDates, _sealTagLogDates, _txHashs, _timestamps);
    }
    
    /**
     * get product status by labelNo and trackingSeq from db
     */
    event GetProductAt(string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate, bytes32 txHash, uint timestamp);
    function getProductAt(string labelNo, string trackingSeq) public constant returns (string , string , string , string , string , string , bytes32 , uint )
    {
        require(isExist(labelNo) == true);
        
        bytes32 _labelNo = stringToBytes32(labelNo);
        bytes32 _trackingSeq = stringToBytes32(trackingSeq);
        
        require(productDB[_labelNo]._sequences[productDB[_labelNo]._products[_trackingSeq]._index] == _trackingSeq);
        
        Product memory pt = productDB[_labelNo]._products[_trackingSeq];
        
        emit GetProductAt(pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._txHash, pt._timestamp);
        return(pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._txHash, pt._timestamp);
    }
    
    /**
     * get product details of last status from db
     */
    event GetProductInfo(string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate, bytes32 txHash, uint timestamp);
    function getProductInfo(string labelNo) public constant returns (string , string , string , string , string , string , bytes32 , uint )
    {
        require(isExist(labelNo) == true);
        bytes32 __labelNo = stringToBytes32(labelNo);
        
        require(productDB[__labelNo]._sequences.length > 0);
        bytes32 lastStatus = productDB[__labelNo]._sequences[productDB[__labelNo]._sequences.length - 1];
        
        Product memory pt = productDB[__labelNo]._products[lastStatus];
        
        emit GetProductInfo(pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._txHash, pt._timestamp);
        return (pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._txHash, pt._timestamp);
    }
    
    /**
     * get product details by txHash
     */
    event GetTransaction(bytes32 labelNo, string id, string name, string shipmentId, string countryOrigin, string expireDate, string sealTagLogDate, uint timestamp);
    function getTransaction(bytes32 txHash) public view returns (bytes32 , string , string , string , string , string , string , uint )
    {
        require(hashs.length!=0 && hashs[hashMap[txHash]._index]==txHash);
        
        Product memory pt = productDB[hashMap[txHash]._labelNo]._products[hashMap[txHash]._sequence];
        
        emit GetTransaction(hashMap[txHash]._labelNo, pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._timestamp);
        return (hashMap[txHash]._labelNo, pt._id, pt._name, pt._shipmentId, pt._countryOrigin, pt._expireDate, pt._sealTagLogDate, pt._timestamp);
    }
    
    /**
     * get all count of businesses from db
     */
    function getProductCount() public constant returns (uint count)
    {
        return labels.length;
    }
    
    /**
     * constructor with business name of contract
     */
    function setBusinessName(string bizName) onlyOwner public
    {
        require(isEmptyString(bizName) == false);
        BUSINESSNAME = bizName;
    }
    
    /**
     * convert string to bytes32
     */
    function stringToBytes32(string memory source) internal view returns (bytes32 result) 
    {
        if (isEmptyString(source)) return 0x0;

        assembly {
            result := mload(add(source, 32))
        }
    }
    
    /**
     * check if string is empty
     */
    function isEmptyString(string str) internal view returns (bool)
    {
        bytes memory tempEmptyStringTest = bytes(str);
        if (tempEmptyStringTest.length == 0) return true;
        
        return false;
    }
    
    /**
     * check if both strings are equals
     */
    function isEqual(string str1, string str2) internal constant returns (bool)
    {
        if(keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2))) return true;
        
        return false;
    }
}