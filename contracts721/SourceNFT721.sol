// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



interface IWagyuRouter {
    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);
}

contract VelhallaLand721 is ERC721PresetMinterPauserAutoId, Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    address constant ADDRESS_USDT = payable(0x01445C31581c354b7338AC35693AB2001B50b9aE);    // Velas USDT address
    address constant ADDRESS_SCAR = payable(0x8d9fB713587174Ee97e91866050c383b5cEE6209);    // Velas SCAR addres
    
    Counters.Counter[5] private tokenIdCounter;      // counter land id count

    IWagyuRouter wagyuRouter = IWagyuRouter(0x3D1c58B6d4501E34DF37Cf0f664A58059a188F00);    // Velas WagyuRouter address

    bool public isExchangeRateUsed = true;

    uint256 public constant MAX_INT = 2**256 - 1;
    uint256 private maxLandCardStar = 5;

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
    uint256[5] public IDBase = [200000001, 300000001, 400000001, 500000001, 100000001];

    uint256 private prDenominatorOfCHL = 1000;
    uint256[4] private prOfCHL;   // Probability of CrystalHighlands in LandChest

    // Price of Land Star Upgrade (USDT)
    uint256 public priceDenominatorOfLandCardStarUpgradeByUsdt = 10;
    uint256[5][50] public priceOfLandCardStarUpgradeByUsdt = [[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25],[20,15,10,5,25]];
    // Price of Land Star Upgrade (SCAR)
    uint256[5][50] public priceOfLandCardStarUpgradeByScar = [[MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT], [MAX_INT, MAX_INT, MAX_INT, MAX_INT, MAX_INT]];
    
    // priceMultiple
    uint256 public maxPriceMultipleNumberOfGroup = 5;
    uint256[5] public maxPriceMultipleNumberInGroup = [50, 100, 200, 300, 0];
    uint256[5] public priceMultipleRatio = [15,20,30,40,10];   // priceMultipleRatio / priceMultipleRatioDenominator
    uint256 public priceMultipleRatioDenominator = 10; 
    uint256[][5] tokenIdGroup;
    

    // Probability of Land Star Upgrade Critical Hit: probabilityOfLandCardStarUpgradeCriticalHit / prDenominatorOfLandCardStarUpgradeCriticalHit
    uint256 private prDenominatorOfLandCardStarUpgradeCriticalHit = 10000;
    uint256[5][50] private probabilityOfLandCardStarUpgradeCriticalHit;
    // Probability of Land  Star Upgrade: probabilityOfLandCardStarUpgrade / prDenominatorOfLandCardStarUpgrade
    uint256 private prDenominatorOfLandCardStarUpgrade = 100;
    uint256[5][50] private probabilityOfLandCardStarUpgrade;
    
    //GRASSLANDS_MAX_SUPPLY:32000 , TUNDRA_MAX_SUPPLY:32000 , MOLTENBARRENS_MAX_SUPPLY:32000 , WASTELANDS_MAX_SUPPLY:61900 , CRYSTALHIGHLANDS_MAX_SUPPLY:2100
    uint256[5] public MAX_SUPPLY = [32000, 32000, 32000, 61900, 2100]; 

    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => uint256) public landCardStar; // tokenID => star
    mapping (uint256 => uint256) public landCardType; // tokenID => landtype
    mapping (uint256 => uint256) public priceMultiplyingGroup; // tokenId => ABCDE group

    event UpgradeLandCardStar(uint256 indexed tokenId, uint256 landCardStar);
    event LandChestmint(address indexed user, uint256 indexed land, uint256 landID);

    constructor(uint256[4] memory _prOfCHL, uint256[5][50] memory _probabilityOfLandCardStarUpgradeCriticalHit, uint256[5][50] memory _probabilityOfLandCardStarUpgrade) ERC721PresetMinterPauserAutoId("Velhalla Land 721", "VL721", "")  
    { 
        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland
        allocatedLandsChestNumber = [1500, 1500, 1500, 1500];
        remainingLandsChestNumber = [1500, 1500, 1500, 1500];

        // type 0:grassland, 1:tundra, 2:moltenBarrens, 3:wasteland, 4:crystalHighlands
        allocatedLandsNumber = [1500, 1500, 1500, 1500, 87];
        remainingLandsNumber = [1500, 1500, 1500, 1500, 87];

        prOfCHL = _prOfCHL;
        probabilityOfLandCardStarUpgradeCriticalHit = _probabilityOfLandCardStarUpgradeCriticalHit;
        probabilityOfLandCardStarUpgrade = _probabilityOfLandCardStarUpgrade;
    }

    function mint(address to) public override {
        revert("Original mint deprecated");   // deprecate original ERC721PresetMinterPauserAutoId mint
    }
    function burn(uint256 tokenId) public override {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller should be minter to burn");
        _burn(tokenId);
    }

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

    function getAmountsInScarUsdtPair(
        uint256 amountOutUsdt
    ) public virtual view returns (uint256 amountsInScar) {
        address[] memory path = new address[](2);
        path[0] = ADDRESS_SCAR;
        path[1] = ADDRESS_USDT;

        uint256[] memory amounts = wagyuRouter.getAmountsIn(amountOutUsdt, path);
        amountsInScar = amounts[0];
    }

    // upgrade land card star
    function upgradeLandCardStar(uint256 tokenId) nonReentrant external returns(uint256 landCardStarAfterUpgrade){
        require(landCardStar[tokenId] < maxLandCardStar, string(bytes.concat("STOP: Achieve max land card star level: ", bytes(Strings.toString(maxLandCardStar)))));
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        require( (hasRole(MINTER_ROLE, _msgSender()) || (ownerOf(tokenId) == _msgSender())), "web3 CLI: must have minter role or token owner to upgrade LandCard");

        uint256 landCardStarIndex = landCardStar[tokenId] - 1;
        uint256 landCardTypeIndex = landCardType[tokenId];
        uint256 priceScar;

        if(isExchangeRateUsed){
            uint256 priceUsdt;
            priceUsdt = priceOfLandCardStarUpgradeByUsdt[landCardStarIndex][landCardTypeIndex];
            priceScar = getAmountsInScarUsdtPair(priceUsdt).mul(10**6).div(priceDenominatorOfLandCardStarUpgradeByUsdt);
            priceOfLandCardStarUpgradeByScar[landCardStarIndex][landCardTypeIndex] = priceScar.div(10**18);
        }else{
            priceScar = priceOfLandCardStarUpgradeByScar[landCardStarIndex][landCardTypeIndex].mul(10**18);
        }
        if (priceMultiplyingGroup[tokenId] > priceMultipleRatioDenominator){
            priceScar = priceScar.mul(priceMultipleRatio[priceMultiplyingGroup[tokenId]]).div(priceMultipleRatioDenominator);
        }
        IERC20 scar = IERC20(ADDRESS_SCAR);
        scar.safeTransferFrom(address(msg.sender), payable(address(owner())), priceScar);

        // star upgrade critial hit probability
        uint256 prOfCriHit = probabilityOfLandCardStarUpgradeCriticalHit[landCardStarIndex][landCardTypeIndex];
        uint256 comboCriHit = 0;
        while((random(comboCriHit)%prDenominatorOfLandCardStarUpgradeCriticalHit < prOfCriHit) && ((landCardStarIndex+1) < maxLandCardStar)) {
            if(comboCriHit == 0){
                landCardStarIndex += 2;
            }else{
                landCardStarIndex++;
            }
            prOfCriHit = probabilityOfLandCardStarUpgradeCriticalHit[landCardStarIndex-1][landCardTypeIndex];
            comboCriHit++;
        }

        // star upgrade probability
        if(comboCriHit == 0){
            uint256 prOfStarUpgrade;
            prOfStarUpgrade = probabilityOfLandCardStarUpgrade[landCardStarIndex][landCardTypeIndex];
            if(random(landCardStarIndex)%prDenominatorOfLandCardStarUpgrade < prOfStarUpgrade){
                landCardStarIndex++;
            }
        }
        
        // record landCardStar
        landCardStar[tokenId] = landCardStarIndex + 1;
        // upgrade uri
        _tokenURIs[tokenId] = string(bytes.concat("https://velhalla-game.s3.amazonaws.com/MetaData/Land Card/Planet_1/Star_", bytes(Strings.toString(landCardStar[tokenId])), "/", bytes(Strings.toString(tokenId)), "_", bytes(Strings.toString(landCardStar[tokenId])), ".json"));
        // return land card star after upgrade
        landCardStarAfterUpgrade = landCardStar[tokenId];
        emit UpgradeLandCardStar(tokenId, landCardStarAfterUpgrade);
    }

    // minter upgrade land card star
    function minterUpgradeLandCardStar(uint256 tokenId) external returns(uint256 landCardStarAfterUpgrade){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to upgrade LandCard");
        require(landCardStar[tokenId] < maxLandCardStar, string(bytes.concat("STOP: Achieve max land card star level: ", bytes(Strings.toString(maxLandCardStar)))));
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        landCardStar[tokenId] += 1;
        _tokenURIs[tokenId] = string(bytes.concat("https://velhalla-game.s3.amazonaws.com/MetaData/Land Card/Planet_1/Star_", bytes(Strings.toString(landCardStar[tokenId])), "/", bytes(Strings.toString(tokenId)), "_", bytes(Strings.toString(landCardStar[tokenId])), ".json"));
        landCardStarAfterUpgrade = landCardStar[tokenId];
        emit UpgradeLandCardStar(tokenId, landCardStarAfterUpgrade);
    }

    function getProbabilityOfUpgradeByTokenID(uint256 tokenId) external view returns(uint256 prOfStarUpgrade){
        uint256 landCardStarIndex = landCardStar[tokenId] - 1;
        uint256 landCardTypeIndex = landCardType[tokenId];
        prOfStarUpgrade = probabilityOfLandCardStarUpgrade[landCardStarIndex][landCardTypeIndex];
    }
    function getProbabilityOfUpgradeByLandtypeAndStar(uint256 landtype, uint256 star) external view returns(uint256 prOfStarUpgrade){
        uint256 landCardStarIndex = star - 1;
        uint256 landCardTypeIndex = landtype;
        prOfStarUpgrade = probabilityOfLandCardStarUpgrade[landCardStarIndex][landCardTypeIndex];
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
    function getMaxLandCardStar() external view returns(uint256 _maxLandCardStar){
        _maxLandCardStar = maxLandCardStar;
    }

    
    function setIsExchangeRateUsed(bool _isExchangeRateUsed) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set isExchangeRateUsed");
        isExchangeRateUsed = _isExchangeRateUsed;
    }
    function setPriceOfLandCardStarUpgradeByUsdt(uint256[5][50] memory _priceOfLandCardStarUpgradeByUsdt) external {
        // require(_priceOfLandCardStarUpgradeByUsdt.length >= maxLandCardStar-1, "");
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set Usdt price Of land card star upgrade");
        priceOfLandCardStarUpgradeByUsdt = _priceOfLandCardStarUpgradeByUsdt;
    }
    function getPriceOfLandCardStarUpgradeByUsdt() external view returns(uint256[5][50] memory){
        return priceOfLandCardStarUpgradeByUsdt;
    }
    
    function setPriceOfLandCardStarUpgradeByScar(uint256[5][50] memory _priceOfLandCardStarUpgradeByScar) external {
        // require(_priceOfLandCardStarUpgradeByScar.length >= maxLandCardStar-1, "");
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set SCAR price Of land card star upgrade");
        priceOfLandCardStarUpgradeByScar = _priceOfLandCardStarUpgradeByScar;
    }
    function getPriceOfLandCardStarUpgradeByScar() external view returns(uint256[5][50] memory){
        return priceOfLandCardStarUpgradeByScar;
    }

    function setProbabilityOfLandCardStarUpgradeCriticalHit(uint256[5][50] memory _probabilityOfLandCardStarUpgradeCriticalHit) external {
        // require(_probabilityOfLandCardStarUpgradeCriticalHit.length >= maxLandCardStar-1, "");
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set probability of land card star upgrade(critical hit)");
        probabilityOfLandCardStarUpgradeCriticalHit = _probabilityOfLandCardStarUpgradeCriticalHit;
    }
    function getProbabilityOfLandCardStarUpgradeCriticalHit() external view returns(uint256[5][50] memory){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get probability of land card star upgrade(critical hit)");
        return probabilityOfLandCardStarUpgradeCriticalHit;
    }

    function setProbabilityOfLandCardStarUpgrade(uint256[5][50] memory _probabilityOfLandCardStarUpgrade) external {
        // require(_probabilityOfLandCardStarUpgrade.length >= maxLandCardStar-1, "");
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set probability of land card star upgrade");
        probabilityOfLandCardStarUpgrade = _probabilityOfLandCardStarUpgrade;
    }
    function getProbabilityOfLandCardStarUpgrade() external view returns(uint256[5][50] memory){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get probability of land card star upgrade");
        return probabilityOfLandCardStarUpgrade;
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
    function setPriceDenominatorOfLandCardStarUpgradeByUsdt(uint256 _priceDenominatorOfLandCardStarUpgradeByUsdt) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set priceDenominatorOfLandCardStarUpgradeByUsdt");
        priceDenominatorOfLandCardStarUpgradeByUsdt = _priceDenominatorOfLandCardStarUpgradeByUsdt;
    }
    function getPriceDenominatorOfLandCardStarUpgradeByUsdt() external view returns(uint256){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get priceDenominatorOfLandCardStarUpgradeByUsdt");
        return priceDenominatorOfLandCardStarUpgradeByUsdt;
    }
    function setPrDenominatorOfLandCardStarUpgradeCriticalHit(uint256 _prDenominatorOfLandCardStarUpgradeCriticalHit) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set prDenominatorOfLandCardStarUpgradeCriticalHit");
        prDenominatorOfLandCardStarUpgradeCriticalHit = _prDenominatorOfLandCardStarUpgradeCriticalHit;
    }
    function getPrDenominatorOfLandCardStarUpgradeCriticalHit() external view returns(uint256){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get prDenominatorOfLandCardStarUpgradeCriticalHit");
        return prDenominatorOfLandCardStarUpgradeCriticalHit;
    }
    function setPrDenominatorOfLandCardStarUpgrade(uint256 _prDenominatorOfLandCardStarUpgrade) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set prDenominatorOfLandCardStarUpgrade");
        prDenominatorOfLandCardStarUpgrade = _prDenominatorOfLandCardStarUpgrade;
    }
    function getPrDenominatorOfLandCardStarUpgrade() external view returns(uint256){
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to get prDenominatorOfLandCardStarUpgrade");
        return prDenominatorOfLandCardStarUpgrade;
    }

    // price Multiplying
    function setMaxPriceMultipleNumberOfGroup(uint256 _maxPriceMultipleNumberOfGroup) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set maxPriceMultipleNumberOfGroup");
        maxPriceMultipleNumberOfGroup = _maxPriceMultipleNumberOfGroup;
    }
    function setPriceMultipleRatio(uint256[5] memory _priceMultipleRatio) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set priceMultipleRatio");
        priceMultipleRatio = _priceMultipleRatio;
    }
    function setPriceMultipleRatioDenominator(uint256 _priceMultipleRatioDenominator) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set priceMultipleRatioDenominator");
        priceMultipleRatioDenominator = _priceMultipleRatioDenominator;
    }
    function setTokenIdGroup(uint256 _tokenId, uint256 groupIndex) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set tokenIdGroup");
        require(groupIndex < maxPriceMultipleNumberOfGroup, string(bytes.concat("Group index exceed limit: ", bytes(Strings.toString(maxPriceMultipleNumberOfGroup-1)))));
        require(tokenIdGroup[groupIndex].length < maxPriceMultipleNumberInGroup[groupIndex], string(bytes.concat("Number in group exceed limit: ", bytes(Strings.toString(maxPriceMultipleNumberInGroup[groupIndex])))));
        priceMultiplyingGroup[_tokenId] = groupIndex;
        tokenIdGroup[groupIndex].push(_tokenId);
    }
    function setMaxPriceMultipleNumberInGroup(uint256[5] memory _maxPriceMultipleNumberInGroup) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to set maxPriceMultipleNumberInGroup");
        maxPriceMultipleNumberInGroup = _maxPriceMultipleNumberInGroup;
    }

    // get star upgrade scar price after price Multiplying
    function getLandCardUpgradeStarScar(uint256[] memory tokenId) external view returns (uint256[] memory price){
        price = new uint256[](tokenId.length);
        for (uint i = 0; i < tokenId.length; i++){
            uint256 landCardStarIndex = landCardStar[tokenId[i]] - 1;
            uint256 landCardTypeIndex = landCardType[tokenId[i]];
            uint256 priceScar;

            if(isExchangeRateUsed){
                uint256 priceUsdt;
                priceUsdt = priceOfLandCardStarUpgradeByUsdt[landCardStarIndex][landCardTypeIndex];
                priceScar = getAmountsInScarUsdtPair(priceUsdt).mul(10**6).div(priceDenominatorOfLandCardStarUpgradeByUsdt);
            }else{
                priceScar = priceOfLandCardStarUpgradeByScar[landCardStarIndex][landCardTypeIndex].mul(10**18);
            }
            if (priceMultiplyingGroup[tokenId[i]] > priceMultipleRatioDenominator){
                priceScar = priceScar.mul(priceMultipleRatio[priceMultiplyingGroup[tokenId[i]]]).div(priceMultipleRatioDenominator);
            }
            price[i] = priceScar.div(10**18);
        }
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
}