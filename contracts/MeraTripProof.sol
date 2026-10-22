// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MeraTripProof
 * @notice Smart contract for recording digital travel certificates (Proof of Visit)
 *         for the MeraTrip Mount Merapi Ecotourism application.
 * @dev Records only canonical SHA-256 hashes and proof identifiers.
 *      No Personally Identifiable Information (PII) is stored on-chain.
 */
contract MeraTripProof {
    // Structure holding minimal proof details on-chain
    struct ProofRecord {
        bytes32 proofHash;      // Canonical SHA-256 hash of trip summary snapshot
        uint256 timestamp;      // Block timestamp when recorded
        address recorder;       // Relayer or sender address
    }

    // Mapping from unique proofId to ProofRecord
    mapping(bytes32 => ProofRecord) private _proofs;

    // Total count of proofs recorded
    uint256 public totalProofsCount;

    // Contract owner / relayer admin
    address public owner;

    // Events
    event ProofRecorded(
        bytes32 indexed proofId,
        bytes32 indexed proofHash,
        address indexed recorder,
        uint256 timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "MeraTripProof: Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @notice Records a new digital trip certificate.
     * @param proofId Unique 32-byte identifier for the proof.
     * @param proofHash SHA-256 canonical hash of the trip summary.
     */
    function recordProof(bytes32 proofId, bytes32 proofHash) external {
        require(proofId != bytes32(0), "MeraTripProof: Invalid proofId");
        require(proofHash != bytes32(0), "MeraTripProof: Invalid proofHash");
        require(_proofs[proofId].timestamp == 0, "MeraTripProof: Proof already recorded");

        _proofs[proofId] = ProofRecord({
            proofHash: proofHash,
            timestamp: block.timestamp,
            recorder: msg.sender
        });

        totalProofsCount += 1;

        emit ProofRecorded(proofId, proofHash, msg.sender, block.timestamp);
    }

    /**
     * @notice Reads proof details by proofId.
     * @param proofId Unique 32-byte identifier.
     * @return proofHash The recorded SHA-256 hash.
     * @return timestamp The block timestamp of recording.
     * @return recorder The address that submitted the transaction.
     */
    function getProof(bytes32 proofId)
        external
        view
        returns (
            bytes32 proofHash,
            uint256 timestamp,
            address recorder
        )
    {
        ProofRecord memory record = _proofs[proofId];
        require(record.timestamp != 0, "MeraTripProof: Proof not found");
        return (record.proofHash, record.timestamp, record.recorder);
    }

    /**
     * @notice Verifies whether a given proofId matches a specific proofHash.
     * @param proofId Unique 32-byte identifier.
     * @param proofHash Expected SHA-256 hash.
     * @return isValid True if proof exists and hash matches exactly.
     */
    function verifyProof(bytes32 proofId, bytes32 proofHash)
        external
        view
        returns (bool isValid)
    {
        ProofRecord memory record = _proofs[proofId];
        if (record.timestamp == 0) {
            return false;
        }
        return record.proofHash == proofHash;
    }

    /**
     * @notice Checks if a proofId has already been recorded.
     */
    function isProofRecorded(bytes32 proofId) external view returns (bool) {
        return _proofs[proofId].timestamp != 0;
    }

    /**
     * @notice Transfers ownership of contract to new address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MeraTripProof: New owner cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
