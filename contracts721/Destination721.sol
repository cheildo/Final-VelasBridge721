// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract VelhallaLand721 is ERC721PresetMinterPauserAutoId, Ownable, ReentrancyGuard, Initializable{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Token name
    string private _name;
    // Token symbol
    string private _symbol;

    address constant ADDRESS_USDT = payable(0x55d398326f99059fF775485246999027B3197955);    // BSC-USD address, Decimals:6
    address constant ADDRESS_SCAR = payable(0x8d9fB713587174Ee97e91866050c383b5cEE6209);    // BSC SCAR addres
    
    Counters.Counter[5] private tokenIdCounter;      // counter land id count

    uint256 public constant MAX_INT = 2**256 - 1;
    uint256 private maxLandCardStar;

    // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland, 4:crystalHighlands
    uint256 private constant grasslands = 0;
    uint256 private constant tundra = 1;
    uint256 private constant moltenBarrens = 2;
    uint256 private constant wastelands = 3;
    uint256 private constant crystalHighlands = 4;

    uint256[4] public allocatedLandsChestNumber;
    uint256[4] public remainingLandsChestNumber;

    uint256[5] public allocatedLandsNumber; 
    uint256[5] public remainingLandsNumber;
    uint256[5] public IDBase;

    uint256 private prDenominatorOfCHL;
    uint256[4] private prOfCHL;   // Probability of CrystalHighlands in LandChest
    
    //GRASSLANDS_MAX_SUPPLY:32000 , TUNDRA_MAX_SUPPLY:32000 , MOLTENBARRENS_MAX_SUPPLY:32000 , WASTELANDS_MAX_SUPPLY:61900 , CRYSTALHIGHLANDS_MAX_SUPPLY:2100
    uint256[5] public MAX_SUPPLY;

    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => uint256) public landCardStar; // tokenID => star
    mapping (uint256 => uint256) public landCardType; // tokenID => landtype
    mapping (uint256 => uint256) public priceMultiplyingGroup; // tokenId => ABCDE group

    event UpgradeLandCardStar(uint256 indexed tokenId, uint256 landCardStar);
    event LandChestmint(address indexed user, uint256 indexed land, uint256 landID);


    constructor() ERC721PresetMinterPauserAutoId("Velhalla Land 721", "VL721", "")  
    {
        
    }
    
    function initialize(
        string memory name_,
        string memory symbol_
    ) initializer external {

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        _transferOwnership(_msgSender());

        _name = name_;
        _symbol = symbol_;

        maxLandCardStar = 5;

        IDBase = [200000001, 300000001, 400000001, 500000001, 100000001];

        prDenominatorOfCHL = 1000;
        // prOfCHL = _prOfCHL;   // Probability of CrystalHighlands in LandChest


        //GRASSLANDS_MAX_SUPPLY:32000 , TUNDRA_MAX_SUPPLY:32000 , MOLTENBARRENS_MAX_SUPPLY:32000 , WASTELANDS_MAX_SUPPLY:61900 , CRYSTALHIGHLANDS_MAX_SUPPLY:2100
        MAX_SUPPLY = [32000, 32000, 32000, 61900, 2100]; 

        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland
        allocatedLandsChestNumber = [1500, 1500, 1500, 1500];
        remainingLandsChestNumber = [1500, 1500, 1500, 1500];

        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland, 4:crystalHighlands
        allocatedLandsNumber = [1500, 1500, 1500, 1500, 87];
        remainingLandsNumber = [1500, 1500, 1500, 1500, 87];
    }

    function mint(address to) public pure override {
        revert("Original mint deprecated");   // deprecate original ERC721PresetMinterPauserAutoId mint
    }


    function ownerMintLand(uint256 amount, uint256 baseID, uint256 landtype, uint256 landstar) whenNotPaused external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to open LandChest");
        require(landstar > 0, "Landstar must be large than 0");
        for(uint256 tokenId=baseID; tokenId<amount+baseID; tokenId++) {
            landCardStar[tokenId] = landstar;
            landCardType[tokenId] = landtype;
            _mint(_msgSender(), tokenId);
            _tokenURIs[tokenId] = string(bytes.concat("https://velhalla-game.s3.amazonaws.com/MetaData/Land Card/Planet_1/Star_", bytes(Strings.toString(landCardStar[tokenId])), "/", bytes(Strings.toString(tokenId)), "_", bytes(Strings.toString(landCardStar[tokenId])), ".json"));
        }
    }


    function burn(uint256 tokenId) public override {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller should be minter to burn");
        _burn(tokenId);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata tokenIds) public {
    require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "Caller is not token owner or approved"
        );
        for(uint256 i=0 ; i<tokenIds.length ; i++) {
            safeTransferFrom(from, to, tokenIds[i]);
        }
    }
    // function initializeOwnership() external {
    //     require(hasRole(MINTER_ROLE, _msgSender()), "Caller should be minter to initialize Ownership");
    //     require(owner() == address(0), "Ownable: Owner must be the zero address without being set");
    //     _transferOwnership(_msgSender());
    // }

    // Random function
    function random(uint256 i) private view returns (uint256) {
        return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, i)));
    }

    // land mint. Call by openLandChest function after random pick
    function mintLand(address to, uint256 landtype) whenNotPaused private returns(uint256 tokenId){
        require(tokenIdCounter[landtype].current() < MAX_SUPPLY[landtype], "Land is insufficient");

        tokenId = tokenIdCounter[landtype].current() + IDBase[landtype];
        landCardStar[tokenId] = 1;
        landCardType[tokenId] = landtype;
        _mint(to, tokenId);
        _tokenURIs[tokenId] = string(bytes.concat("https://velhalla-game.s3.amazonaws.com/MetaData/Land Card/Planet_1/Star_", bytes(Strings.toString(landCardStar[tokenId])), "/", bytes(Strings.toString(tokenId)), "_", bytes(Strings.toString(landCardStar[tokenId])), ".json"));

        tokenIdCounter[landtype].increment();
        remainingLandsNumber[landtype] -= 1;
        emit LandChestmint(to, landtype, tokenId);
        return (tokenId);
    }
    // Open LandChest
    function openLandChest(address to, uint256 landChestType, uint256 i) whenNotPaused external returns(uint256 landtype, uint256 tokenId){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to open LandChest");
        require(remainingLandsChestNumber[landChestType] != 0, "LandChest is insufficient");

        if((random(i)%prDenominatorOfCHL < prOfCHL[landChestType]) && (remainingLandsNumber[crystalHighlands] != 0)){ 
            tokenId = mintLand(to, crystalHighlands);
            landtype = crystalHighlands;
        }else{
            tokenId = mintLand(to, landChestType);
            landtype = landChestType;
        }
        remainingLandsChestNumber[landChestType] -= 1;
    }


    // // upgrade land card star for minter and upgrade star contract
    function minterUpgradeLandCardStar(uint256 tokenId) external returns(uint256 landCardStarAfterUpgrade){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to upgrade LandCard");
        require(landCardStar[tokenId] < maxLandCardStar, string(bytes.concat("STOP: Achieve max land card star level: ", bytes(Strings.toString(maxLandCardStar)))));
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        landCardStar[tokenId] += 1;
        _tokenURIs[tokenId] = string(bytes.concat("https://velhalla-game.s3.amazonaws.com/MetaData/Land Card/Planet_1/Star_", bytes(Strings.toString(landCardStar[tokenId])), "/", bytes(Strings.toString(tokenId)), "_", bytes(Strings.toString(landCardStar[tokenId])), ".json"));
        landCardStarAfterUpgrade = landCardStar[tokenId];
        emit UpgradeLandCardStar(tokenId, landCardStarAfterUpgrade);
    }

    function setLandsChestNumber(uint256[4] memory _allocatedLandsChestNumber) whenPaused external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to update LandsChest Number");
        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland
        allocatedLandsChestNumber = _allocatedLandsChestNumber;
        remainingLandsChestNumber = _allocatedLandsChestNumber;
    }
    function getRemainingLandsChestNumber() external view returns(uint256[4] memory) {
        // return remainingLandsChestNumber[landChestType];
        return remainingLandsChestNumber;
    }
    function setLandsNumber(uint256[5] memory _allocatedLandsNumber) whenPaused external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to update Lands Number");
        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland, 4:crystalHighlands
        allocatedLandsNumber = _allocatedLandsNumber;
        remainingLandsNumber = _allocatedLandsNumber;
    }

    function setPrOfCHL(uint256[4] memory _prOfCHL) whenPaused external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to update PrOfCHL");
        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland, 4:crystalHighlands
        prOfCHL = _prOfCHL;
    }
    function getPrOfCHL() external view returns(uint256[4] memory){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get PrOfCHL");
        return prOfCHL;
    }

    function setMaxLandCardStar(uint256 _maxLandCardStar) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set max land card star");
        // require(priceOfLandCardStarUpgradeByUsdt.length >= _maxLandCardStar-1, "");
        // require(priceOfLandCardStarUpgradeByScar.length >= _maxLandCardStar-1, "");
        // require(probabilityOfLandCardStarUpgradeCriticalHit.length >= _maxLandCardStar-1, "");
        // require(probabilityOfLandCardStarUpgrade.length >= _maxLandCardStar-1, "");
        
        maxLandCardStar = _maxLandCardStar;
    }

    function setLandCardStar(uint256[] memory tokenIds, uint256 landstar) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set set landCardStar");
        for (uint256 i = 0; i < tokenIds.length ; i++) {
            landCardStar[tokenIds[i]] = landstar;
        }
    }
    function setLandCardType(uint256[] memory tokenIds, uint256 landtype) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set landCardType");
        for (uint256 i = 0; i < tokenIds.length ; i++) {
            landCardType[tokenIds[i]] = landtype;
        }
    }

    function getMaxLandCardStar() external view returns(uint256 _maxLandCardStar){
        _maxLandCardStar = maxLandCardStar;
    }

    // set Denominator
    function setPrDenominatorOfCHL(uint256 _prDenominatorOfCHL) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set prDenominatorOfCHL");
        prDenominatorOfCHL = _prDenominatorOfCHL;
    }
    function getPrDenominatorOfCHL() external view returns(uint256){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get prDenominatorOfCHL");
        return prDenominatorOfCHL;
    }
 
    // get Land TokenIds and Land TokenURIs
    function getLandTokenIds(address account) external view returns(uint256[] memory){
        uint256 balance = balanceOf(account);
        uint256[] memory landTokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance ; i++) {
            landTokenIds[i] = tokenOfOwnerByIndex(account, i);
        }
        return (landTokenIds);
    }
    function getLandTokenURIs(address account) external view returns(string[] memory){
        uint256 balance = balanceOf(account);
        string[] memory landTokenURIs = new string[](balance);
        for (uint256 i = 0; i < balance ; i++) {
            landTokenURIs[i] = _tokenURIs[tokenOfOwnerByIndex(account, i)];
        }
        return landTokenURIs;
    }


    function setTokenURI(uint256 tokenId, string memory _uri) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to update tokenURI");
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        _tokenURIs[tokenId] = _uri;
    }
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return _tokenURIs[tokenId];
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}