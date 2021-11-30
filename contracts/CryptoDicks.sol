// SPDX-License-Identifier: MIT

pragma solidity >=0.8.3 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "./SafeMath8.sol";

/// @title The main CryptoDicks ERC721 smart contract.
/// @author juliencrn
/// @dev Work in progress, not production ready yet.
contract CryptoDicks is Ownable, ERC721, VRFConsumerBase {
    // Libs
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using SafeMath8 for uint8;
    using SafeCast for uint256;

    Counters.Counter internal _currentSupply;
    Counters.Counter internal _randomNonce;

    // Variable to have a random number from Chainlink
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    // rinkeby: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
    address public VRFCoordinator;
    // rinkeby: 0x01BE23585060835E02B77ef475b0Cc51aA1e0709a
    address public LinkToken;

    // Contract settings
    uint256 public totalSupply = 10_000;
    string internal _currentBaseURI = "http://localhost:5000/";
    uint256 public claimFee = 0.01 ether;

    // NFT properties
    struct Metadata {
        uint8 background;
        uint8 skin;
        uint8 hat;
        uint8 eye;
    }

    // Mapping token ID to Metadata
    mapping(uint256 => Metadata) idToMetadata;

    // Mapping metadata dna to boolean
    mapping(uint256 => bool) private _dnaExists;

    // dev purpose
    // TODO: Remove
    event ReceiveRandom(uint256 randomNumber);

    // Mapping user address with random number
    // mapping(address => uint256) public userToRandomNumber;

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Rinkeby
     * Chainlink VRF Coordinator address: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
     * LINK token address:                0x01BE23585060835E02B77ef475b0Cc51aA1e0709
     * Key Hash: 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
     */
    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash
    )
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721("CryptoDicks", "DICK")
    {
        // Chainlink stuff
        VRFCoordinator = _VRFCoordinator;
        LinkToken = _LinkToken;
        keyHash = _keyhash;
        fee = 0.1 * 10**18; // 0.1 LINK

        // Mint my own NFT tokens.
        for (uint256 i = 0; i < 10; i++) {
            mint();
        }
    }

    function requestNewRandomNumber()
        public
        returns (
            // uint256 userProvidedSeed,
            // string memory name
            bytes32
        )
    {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomNumber)
        internal
        override
    {
        emit ReceiveRandom(_randomNumber);
        randomResult = _randomNumber;
    }

    /// Allow user to mint a token
    /// @dev takes fees then calls mint() internally.
    function claim() external payable {
        require(msg.value == claimFee, "Claiming a NFT costs ether");

        mint();

        // Give ether to the contract owner
        payable(owner()).transfer(claimFee);
    }

    /// Mint a new NFT
    /// @return Created token id
    function mint() internal returns (uint256) {
        require(_currentSupply.current() < totalSupply);

        // Increment the token supply.
        _currentSupply.increment();
        uint256 newTokenId = _currentSupply.current();

        // Generate and save metadata
        idToMetadata[newTokenId] = _createUniqueNFT();

        // Finally, mint!
        _safeMint(msg.sender, newTokenId);

        return newTokenId;
    }

    /// Return the good baseURI overriding the ERC721 method
    function _baseURI() internal view virtual override returns (string memory) {
        return _currentBaseURI;
    }

    /// Allow owner to set new baseURI
    function setBaseURI(string memory _baseUri) public onlyOwner {
        _currentBaseURI = _baseUri;
    }

    /// Allow owner to set new mint fee price, ether price will change.
    function setClaimFee(uint256 _newPrice) external onlyOwner {
        claimFee = _newPrice;
    }

    /// Allow owner to withdraw contract balance.
    /// @dev Ether are stored in the contract when "payable->transfer" is invoked.
    /// TODO Add unit test
    function withdraw() external payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /// For a a given token ID, returns its metadata
    function get(uint256 _tokenId)
        external
        view
        returns (
            uint8,
            uint8,
            uint8,
            uint8
        )
    {
        require(_exists(_tokenId), "Token not minted yet");
        return (
            idToMetadata[_tokenId].background,
            idToMetadata[_tokenId].skin,
            idToMetadata[_tokenId].hat,
            idToMetadata[_tokenId].eye
        );
    }

    /// @return the current supply
    function currentSupply() external view returns (uint256) {
        return _currentSupply.current();
    }

    ////////////////////////////////////////////////////////////
    // Random and Rarity algos
    ////////////////////////////////////////////////////////////

    /// Create unique metadata combination
    /// TODO: Test algos part
    /// @dev this function is the algo part entry point
    /// @dev exec a infinite loop
    /// @dev check and mute the _dnaExists mapping
    /// @return Metadata
    function _createUniqueNFT() internal returns (Metadata memory) {
        uint256 dna;
        uint8 background;
        uint8 skin;
        uint8 hat;
        uint8 eye;

        while (true) {
            // Generate random metadata
            (background, skin, hat, eye) = _generateRandomMetadata();

            // Calc the dna
            dna = uint256(
                keccak256(abi.encodePacked(background, skin, hat, eye))
            );

            // If the new dna is unique, save it and leave the loop
            if (_dnaExists[dna] != true) {
                _dnaExists[dna] = true;
                break;
            }
        }

        return Metadata(background, skin, hat, eye);
    }

    /// Generate a random number
    /// @dev random isn't perfect in Solidity, use Oracle in better approch.
    /// @return uint256 0-999_999
    function _getRandomNumber() internal returns (uint256) {
        _randomNonce.increment();

        bytes memory encoded2 = abi.encodePacked(
            block.difficulty,
            block.timestamp,
            _currentSupply.current(),
            msg.sender,
            _randomNonce.current()
        );
        uint256 rand = uint256(keccak256(encoded2));
        return rand % 1_000_000;
    }

    /// Just generate a Metadata and returns its entries
    /// @dev contains config per metadata attributes
    function _generateRandomMetadata()
        internal
        returns (
            uint8,
            uint8,
            uint8,
            uint8
        )
    {
        return (
            _randomWithRarety(),
            _randomWithRarety(),
            _randomUntil(3),
            _randomUntil(3)
        );
    }

    /// @return random uint8 between 0-n with rarety level
    function _randomUntil(uint8 _optionsCount) internal returns (uint8) {
        return (_getRandomNumber() % _optionsCount).toUint8();
    }

    /// @return random uint8 between 0-7 with rarety level
    function _randomWithRarety() internal returns (uint8) {
        uint256 rand = _getRandomNumber();
        uint8 result;

        if (rand < 1_000) {
            result = 7; // 0.1%
        } else if (rand < 6_000) {
            result = 6; // 0.5%
        } else if (rand < 16_000) {
            result = 5; // 1%
        } else if (rand < 66_000) {
            result = 4; // 5%
        } else if (rand < 166_000) {
            result = 3; // 10%
        } else if (rand < 366_000) {
            result = 2; // 20%
        } else if (rand < 666_000) {
            result = 1; // 30%
        } else {
            result = 0;
        }

        return result;
    }
}
