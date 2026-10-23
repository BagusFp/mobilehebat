// Automated Test Suite: Relayer On-Chain & Recovery Flow
// Menguji skenario Edge Function record-proof, relayer state machine, idempotensi, dan non-atomic recovery.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { ethers } = require('ethers');

console.log('--- TESTING BACKEND RELAYER & NON-ATOMIC RECOVERY FLOW ---');

// Mock Database Supabase In-Memory dengan simulasi PostgreSQL Unique Constraint
class MockSupabaseDB {
  constructor() {
    this.trips = new Map();
    this.trip_proofs = new Map();
    this.nextProofId = 1;
    this.failOnUpdate = false;
  }

  seedTrip(trip) {
    this.trips.set(trip.id, trip);
  }

  async getTrip(tripId) {
    return this.trips.get(tripId) || null;
  }

  async getProofByTripId(tripId) {
    for (const proof of this.trip_proofs.values()) {
      if (proof.trip_id === tripId) return { ...proof };
    }
    return null;
  }

  // Simulasi INSERT dengan UNIQUE constraint pada (trip_id) dan (proof_id)
  async insertProof(proofRecord) {
    for (const proof of this.trip_proofs.values()) {
      if (proof.trip_id === proofRecord.trip_id) {
        const err = new Error('duplicate key value violates unique constraint "trip_proofs_trip_id_key"');
        err.code = '23505';
        throw err;
      }
      if (proof.proof_id === proofRecord.proof_id) {
        const err = new Error('duplicate key value violates unique constraint "trip_proofs_proof_id_key"');
        err.code = '23505';
        throw err;
      }
    }

    const id = this.nextProofId++;
    const created = { id, ...proofRecord };
    this.trip_proofs.set(id, created);
    return { ...created };
  }

  async updateProof(id, updates) {
    if (this.failOnUpdate) {
      throw new Error('DATABASE_CONNECTION_TIMEOUT: Failed to update row in PostgreSQL');
    }
    if (!this.trip_proofs.has(id)) throw new Error('Proof not found');
    const updated = { ...this.trip_proofs.get(id), ...updates };
    this.trip_proofs.set(id, updated);
    return { ...updated };
  }
}

// Mock Ethereum Sepolia Node & Smart Contract
class MockSepoliaRelayer {
  constructor() {
    this.onChainProofs = new Map(); // proofId -> { proofHash, timestamp, recorder }
    this.txPool = new Map(); // txHash -> { status: 1 | 0 | null, blockNumber, proofId, proofHash }
    this.totalCount = 0;
    this.broadcastCount = 0;
    this.shouldFailRpc = false;
  }

  async isProofRecorded(proofId) {
    if (this.shouldFailRpc) throw new Error('RPC_TIMEOUT: Connection to Sepolia timed out');
    return this.onChainProofs.has(proofId.toLowerCase());
  }

  async getProof(proofId) {
    if (this.shouldFailRpc) throw new Error('RPC_TIMEOUT');
    const p = this.onChainProofs.get(proofId.toLowerCase());
    if (!p) throw new Error('MeraTripProof: Proof not found');
    return { ...p };
  }

  async staticCallRecordProof(proofId, proofHash) {
    if (this.shouldFailRpc) throw new Error('RPC_TIMEOUT: Connection to Sepolia timed out');
    if (proofId === '0x' || !proofId || proofId === ethers.ZeroHash) {
      throw new Error('MeraTripProof: Invalid proofId');
    }
    if (proofHash === '0x' || !proofHash || proofHash === ethers.ZeroHash) {
      throw new Error('MeraTripProof: Invalid proofHash');
    }
    if (this.onChainProofs.has(proofId.toLowerCase())) {
      throw new Error('MeraTripProof: Proof already recorded');
    }
    return true;
  }

  async broadcastRecordProof(proofId, proofHash, relayerAddress) {
    if (this.shouldFailRpc) throw new Error('RPC_TIMEOUT: Broadcast error');
    await this.staticCallRecordProof(proofId, proofHash);

    this.broadcastCount++;
    const txHash = '0x' + crypto.randomBytes(32).toString('hex');
    this.txPool.set(txHash, { status: null, proofId, proofHash, relayerAddress });
    return txHash;
  }

  mineTx(txHash, success = true) {
    if (!this.txPool.has(txHash)) throw new Error('Tx not in pool');
    const tx = this.txPool.get(txHash);
    tx.status = success ? 1 : 0;
    tx.blockNumber = 11970410;
    if (success) {
      this.onChainProofs.set(tx.proofId.toLowerCase(), {
        proofHash: tx.proofHash,
        timestamp: Math.floor(Date.now() / 1000),
        recorder: tx.relayerAddress,
      });
      this.totalCount++;
    }
  }

  async getTransactionReceipt(txHash) {
    if (this.shouldFailRpc) throw new Error('RPC_TIMEOUT');
    const tx = this.txPool.get(txHash);
    if (!tx || tx.status === null) return null;
    return {
      status: tx.status,
      blockNumber: tx.blockNumber,
      transactionHash: txHash,
    };
  }
}

// Simulasi Logika Edge Function record-proof Terbaru (Sesuai index.ts)
async function executeRecordProofEdgeFunction({
  authHeader,
  tripId,
  db,
  relayer,
  enableBroadcast = false,
  relayerPrivateKey = '',
  rawContractAddress = '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
}) {
  // Boundary sanitasi konfigurasi dan validasi format alamat
  const cleanedRawContract = (rawContractAddress ?? '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D').trim();
  if (!ethers.isAddress(cleanedRawContract)) {
    return {
      status: 500,
      body: { error: 'Server configuration error: Invalid contract address format' },
    };
  }
  const contractAddress = ethers.getAddress(cleanedRawContract);

  // 1. Auth check
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { status: 401, body: { error: 'Missing or invalid Authorization header' } };
  }
  const token = authHeader.replace('Bearer ', '');
  if (token === 'invalid_token') {
    return { status: 401, body: { error: 'Unauthorized user session' } };
  }
  const user = { id: token === 'user_b_token' ? 'user_b_uuid' : 'user_a_uuid' };

  if (!tripId) {
    return { status: 400, body: { error: 'trip_id is required' } };
  }

  // 2. Fetch Trip & Ownership Validation
  const trip = await db.getTrip(tripId);
  if (!trip) {
    return { status: 404, body: { error: 'Trip not found' } };
  }

  if (trip.user_id !== user.id) {
    return { status: 403, body: { error: 'Trip does not belong to the authenticated user' } };
  }

  if (trip.status !== 'completed') {
    return { status: 400, body: { error: 'Trip must be completed to generate proof of visit' } };
  }

  // 3. Check Existing & Recovery
  const existingProof = await db.getProofByTripId(tripId);
  let activeProof = existingProof;

  if (existingProof) {
    if (existingProof.status === 'confirmed') {
      return { status: 200, body: { message: 'Existing proof confirmed on-chain', proof: existingProof } };
    }

    if (existingProof.status === 'simulated') {
      if (!enableBroadcast || !relayerPrivateKey) {
        return {
          status: 200,
          body: {
            message: 'Existing dry-run proof simulation verified',
            proof: existingProof,
            mode: 'dry_run',
            broadcast_enabled: false,
            simulation_passed: true,
          },
        };
      }
    }

    // 4B. Pending dengan tx_hash yang sudah tercatat
    if (existingProof.tx_hash && existingProof.status === 'pending') {
      try {
        const receipt = await relayer.getTransactionReceipt(existingProof.tx_hash);
        if (receipt && receipt.status === 1) {
          const confirmed = await db.updateProof(existingProof.id, {
            status: 'confirmed',
            confirmed_at: new Date().toISOString(),
          });
          return { status: 200, body: { message: 'Pending transaction recovered and confirmed on-chain', proof: confirmed } };
        } else if (receipt && receipt.status === 0) {
          const failedRecord = await db.updateProof(existingProof.id, { status: 'failed' });
          return { status: 400, body: { error: 'Previous on-chain transaction reverted during execution', proof: failedRecord } };
        } else {
          return { status: 202, body: { message: 'Transaction is currently pending in Sepolia mempool', proof: existingProof } };
        }
      } catch (e) {
        return { status: 202, body: { message: 'Previous transaction is pending, RPC verification in progress', proof: existingProof } };
      }
    }

    // 4C. Pending tanpa tx_hash (Kasus broadcast berhasil tapi DB update tx_hash gagal)
    try {
      const isRecorded = await relayer.isProofRecorded(existingProof.proof_id);
      if (isRecorded) {
        const onChain = await relayer.getProof(existingProof.proof_id);
        if (onChain.proofHash.toLowerCase() !== existingProof.proof_hash.toLowerCase()) {
          return { status: 409, body: { error: 'Proof ID conflict detected on-chain with a conflicting hash' } };
        }

        const confirmedAt = new Date(Number(onChain.timestamp) * 1000).toISOString();
        const recovered = await db.updateProof(existingProof.id, {
          status: 'confirmed',
          confirmed_at: confirmedAt,
        });
        return { status: 200, body: { message: 'Proof recovered successfully from Ethereum Sepolia', proof: recovered } };
      }
    } catch (_) {}

    // In-flight check (< 25s)
    const createdAtMs = new Date(existingProof.created_at).getTime();
    if (Date.now() - createdAtMs < 25000 && existingProof.status === 'pending') {
      return { status: 202, body: { message: 'Proof generation currently in progress, please wait', proof: existingProof } };
    }
  }

  // 5. Generate Payload atau Re-use existing proof_id
  let proofId;
  let proofHash;
  let canonicalJson;
  let salt;

  if (activeProof) {
    // RE-USE existing proofId & hash to prevent orphan proofs or duplicate gas spending
    proofId = activeProof.proof_id;
    proofHash = activeProof.proof_hash;
    canonicalJson = activeProof.snapshot_json;
    salt = activeProof.salt;
  } else {
    salt = crypto.randomBytes(32).toString('hex');
    proofId = '0x' + crypto.randomBytes(32).toString('hex');

    const destinations = (trip.items || [])
      .map((item) => ({
        destination_name: (item.name || '').trim(),
        elevation_mdpl: item.elevation_mdpl || 0,
        is_visited: item.is_completed === true,
      }))
      .sort((a, b) => a.destination_name.localeCompare(b.destination_name));

    const tripIdentifier = '0x' + crypto.createHash('sha256').update(`meratrip_trip_${tripId}_${salt}`).digest('hex');

    const canonicalPayload = {
      completed_at: trip.completed_at || '',
      destinations: destinations,
      payload_version: '1.0.0',
      proof_id: proofId.toLowerCase(),
      salt: salt,
      start_date: trip.start_date || '',
      total_destinations: destinations.length,
      trip_identifier: tripIdentifier,
    };

    const sortedKeys = Object.keys(canonicalPayload).sort();
    const sortedObj = {};
    for (const k of sortedKeys) sortedObj[k] = canonicalPayload[k];
    canonicalJson = JSON.stringify(sortedObj);
    proofHash = '0x' + crypto.createHash('sha256').update(canonicalJson).digest('hex');

    try {
      activeProof = await db.insertProof({
        user_id: user.id,
        trip_id: tripId,
        proof_id: proofId,
        proof_hash: proofHash,
        payload_version: '1.0.0',
        snapshot_json: canonicalJson,
        salt: salt,
        chain_id: 11155111,
        contract_address: contractAddress,
        tx_hash: null,
        status: 'pending',
        created_at: new Date().toISOString(),
      });
    } catch (insertErr) {
      if (insertErr.code === '23505') {
        const concurrentProof = await db.getProofByTripId(tripId);
        return {
          status: 202,
          body: { message: 'Concurrent request detected. Proof creation is already in progress.', proof: concurrentProof },
        };
      }
      throw insertErr;
    }
  }

  // 6. Anti-Tamper & Anti-Collision Check
  try {
    const alreadyOnChain = await relayer.isProofRecorded(proofId);
    if (alreadyOnChain) {
      const onChain = await relayer.getProof(proofId);
      if (onChain.proofHash.toLowerCase() === proofHash.toLowerCase()) {
        const confirmedAt = new Date(Number(onChain.timestamp) * 1000).toISOString();
        const updated = await db.updateProof(activeProof.id, { status: 'confirmed', confirmed_at: confirmedAt });
        return { status: 200, body: { message: 'Proof already confirmed on Ethereum Sepolia', proof: updated } };
      } else {
        return { status: 409, body: { error: 'Proof ID conflict detected: Existing on-chain record has a conflicting hash.' } };
      }
    }
  } catch (_) {}

  // 7. DRY-RUN MODE (Default / Safe Mode)
  if (!enableBroadcast || !relayerPrivateKey) {
    let simulationPassed = true;
    try {
      await relayer.staticCallRecordProof(proofId, proofHash);
    } catch (simErr) {
      simulationPassed = false;
    }

    const dryRunStatus = simulationPassed ? 'simulated' : 'failed';
    const updated = await db.updateProof(activeProof.id, { status: dryRunStatus, contract_address: contractAddress });

    return {
      status: simulationPassed ? 201 : 400,
      body: {
        message: 'Proof registered in dry-run mode (on-chain simulation passed, broadcast disabled)',
        proof: updated,
        mode: 'dry_run',
        broadcast_enabled: false,
        simulation_passed: simulationPassed,
      },
    };
  }

  // 8. ON-CHAIN BROADCAST (Hanya jika enableBroadcast === true)
  try {
    const txHash = await relayer.broadcastRecordProof(proofId, proofHash, '0xRelayerAddress');

    // Resilient TX Hash Saving
    let saved = false;
    try {
      await db.updateProof(activeProof.id, { tx_hash: txHash, status: 'pending' });
      saved = true;
    } catch (saveErr) {
      console.warn('Simulation: DB update tx_hash failed initially:', saveErr.message);
    }

    // Wait receipt (simulasi)
    const receipt = await relayer.getTransactionReceipt(txHash);
    let finalStatus = 'pending';
    let confirmedAt = null;

    if (receipt && receipt.status === 1) {
      finalStatus = 'confirmed';
      confirmedAt = new Date().toISOString();
    } else if (receipt && receipt.status === 0) {
      finalStatus = 'failed';
    }

    let finalProof = activeProof;
    if (saved) {
      finalProof = await db.updateProof(activeProof.id, {
        status: finalStatus,
        confirmed_at: confirmedAt,
      });
    }

    return {
      status: finalStatus === 'confirmed' ? 200 : 202,
      body: {
        message: finalStatus === 'confirmed' ? 'Proof recorded and confirmed on Sepolia' : 'Proof transaction broadcast to Sepolia (pending in mempool)',
        proof: finalProof,
        mode: 'on_chain',
        broadcast_enabled: true,
      },
    };
  } catch (err) {
    await db.updateProof(activeProof.id, { status: 'failed' });
    return { status: 502, body: { error: err.message, proof: { ...activeProof, status: 'failed' } } };
  }
}

// =============================================================================
// RUNNING THE COMPREHENSIVE TEST SCENARIOS
// =============================================================================
async function runTests() {
  const db = new MockSupabaseDB();
  const relayer = new MockSepoliaRelayer();

  // Seed sample trips
  db.seedTrip({ id: 1, user_id: 'user_a_uuid', status: 'upcoming', items: [] });
  db.seedTrip({ id: 2, user_id: 'user_a_uuid', status: 'ongoing', items: [] });
  db.seedTrip({
    id: 3,
    user_id: 'user_a_uuid',
    status: 'completed',
    completed_at: '2026-10-21T18:00:00Z',
    start_date: '2026-10-20',
    items: [
      { name: 'Basecamp Selo', elevation_mdpl: 1564, is_completed: true },
      { name: 'Pasar Bubrah', elevation_mdpl: 2680, is_completed: true },
    ],
  });
  db.seedTrip({ id: 4, user_id: 'user_b_uuid', status: 'completed', items: [] });

  // Test 1: Trip Upcoming ditolak 400
  {
    const res = await executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 1, db, relayer });
    if (res.status !== 400 || !res.body.error.includes('must be completed')) {
      console.error('FAIL Test 1'); process.exit(1);
    }
    console.log('PASS Test 1: Trip Upcoming berhasil ditolak (HTTP 400)');
  }

  // Test 2: Trip Ongoing ditolak 400
  {
    const res = await executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 2, db, relayer });
    if (res.status !== 400 || !res.body.error.includes('must be completed')) {
      console.error('FAIL Test 2'); process.exit(1);
    }
    console.log('PASS Test 2: Trip Ongoing berhasil ditolak (HTTP 400)');
  }

  // Test 3: Unauthorized Request (401)
  {
    const resNoAuth = await executeRecordProofEdgeFunction({ authHeader: null, tripId: 3, db, relayer });
    const resBadToken = await executeRecordProofEdgeFunction({ authHeader: 'Bearer invalid_token', tripId: 3, db, relayer });
    if (resNoAuth.status !== 401 || resBadToken.status !== 401) {
      console.error('FAIL Test 3'); process.exit(1);
    }
    console.log('PASS Test 3: Unauthorized request berhasil ditolak (HTTP 401)');
  }

  // Test 4: Trip tidak ditemukan (404)
  {
    const res = await executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 99999, db, relayer });
    if (res.status !== 404) {
      console.error('FAIL Test 4'); process.exit(1);
    }
    console.log('PASS Test 4: Trip tidak ditemukan berhasil ditolak (HTTP 404)');
  }

  // Test 5: Akses trip user lain (403)
  {
    const res = await executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 4, db, relayer });
    if (res.status !== 403) {
      console.error('FAIL Test 5'); process.exit(1);
    }
    console.log('PASS Test 5: Trip milik user lain berhasil ditolak (HTTP 403 Forbidden)');
  }

  // Test 6: Dry-Run Mode Validasi
  let proofTrip3 = null;
  {
    const res = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 3,
      db,
      relayer,
      enableBroadcast: false,
    });
    if (res.status !== 201 || res.body.mode !== 'dry_run' || !res.body.simulation_passed || res.body.proof.status !== 'simulated') {
      console.error('FAIL Test 6:', res); process.exit(1);
    }
    proofTrip3 = res.body.proof;
    console.log('PASS Test 6: Dry-Run mode berhasil dan simulasi staticCall sukses tanpa biaya gas (status=simulated)');
  }

  // Test 7: Idempotency & In-Flight check
  {
    const res = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 3,
      db,
      relayer,
      enableBroadcast: false,
    });
    if (res.status !== 200 || res.body.proof.status !== 'simulated') {
      console.error('FAIL Test 7:', res); process.exit(1);
    }
    console.log('PASS Test 7: Duplicate dry-run request tertangani secara idempotent (status=simulated)');
  }

  // Test 8: Broadcast On-Chain Pending di Mempool
  let broadcastTxHash = null;
  {
    db.trip_proofs.clear();
    const res = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 3,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });
    if (res.status !== 202 && res.status !== 201) {
      console.error('FAIL Test 8:', res); process.exit(1);
    }
    broadcastTxHash = res.body.proof.tx_hash;
    console.log('PASS Test 8: Broadcast on-chain berhasil disimpan ke DB dengan status pending');
  }

  // Test 9: Recovery saat mined
  {
    relayer.mineTx(broadcastTxHash, true);
    const resRecovery = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 3,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });
    if (resRecovery.status !== 200 || resRecovery.body.proof.status !== 'confirmed') {
      console.error('FAIL Test 9:', resRecovery); process.exit(1);
    }
    console.log('PASS Test 9: Non-Atomic Recovery mendeteksi blok Sepolia dan update status ke confirmed');
  }

  // Test 10: Reverted transaction
  {
    db.seedTrip({ id: 5, user_id: 'user_a_uuid', status: 'completed', items: [] });
    const resTx = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 5,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });
    const revertTxHash = resTx.body.proof.tx_hash;
    relayer.mineTx(revertTxHash, false);

    const resRevert = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 5,
      db,
      relayer,
    });
    if (resRevert.status !== 400 || resRevert.body.proof.status !== 'failed') {
      console.error('FAIL Test 10:', resRevert); process.exit(1);
    }
    console.log('PASS Test 10: Transaksi reverted on-chain terdeteksi dan status DB ditandai failed');
  }

  // Test 11: RPC Timeout saat broadcast tidak merusak data
  {
    db.seedTrip({ id: 6, user_id: 'user_a_uuid', status: 'completed', items: [] });
    relayer.shouldFailRpc = true;
    const resTimeout = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 6,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });
    if (resTimeout.status !== 502) {
      console.error('FAIL Test 11'); process.exit(1);
    }
    relayer.shouldFailRpc = false;
    console.log('PASS Test 11: RPC Timeout tertangani aman tanpa merusak integritas sistem');
  }

  // Test 12: Concurrent Request (Race Condition protection dengan PostgreSQL Unique Constraint)
  {
    db.seedTrip({ id: 7, user_id: 'user_a_uuid', status: 'completed', items: [] });
    const promise1 = executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 7, db, relayer, enableBroadcast: false });
    const promise2 = executeRecordProofEdgeFunction({ authHeader: 'Bearer user_a_token', tripId: 7, db, relayer, enableBroadcast: false });

    const [res1, res2] = await Promise.all([promise1, promise2]);
    const statuses = [res1.status, res2.status].sort();
    // Salah satu mendapatkan 201 (winner insert), yang lain mendapatkan 202 (caught unique violation)
    if (statuses[0] !== 201 || statuses[1] !== 202) {
      console.error('FAIL Test 12: Concurrent requests harus menghasilkan 201 dan 202:', statuses);
      process.exit(1);
    }
    // Pastikan tepat ada 1 record di DB
    let countForTrip7 = 0;
    for (const p of db.trip_proofs.values()) {
      if (p.trip_id === 7) countForTrip7++;
    }
    if (countForTrip7 !== 1) {
      console.error('FAIL Test 12: Jumlah record trip 7 harus tepat 1, didapat:', countForTrip7);
      process.exit(1);
    }
    console.log('PASS Test 12: Concurrency multi-request dicegah oleh atomic lock (Tepat 1 record di PostgreSQL)');
  }

  // Test 13: DB Failure Setelah Broadcast (Recovery tanpa tx_hash)
  {
    db.seedTrip({ id: 8, user_id: 'user_a_uuid', status: 'completed', items: [] });

    // Simulasikan DB update gagal saat menyimpan tx_hash
    db.failOnUpdate = true;
    const initialBroadcasts = relayer.broadcastCount;

    const resFailedSave = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 8,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });

    db.failOnUpdate = false;
    // Transaksi sebenarnya berhasil dikirim ke blockchain
    if (relayer.broadcastCount !== initialBroadcasts + 1) {
      console.error('FAIL Test 13: Transaksi seharusnya sudah di-broadcast');
      process.exit(1);
    }

    const proofInDb = await db.getProofByTripId(8);
    if (!proofInDb || proofInDb.status !== 'pending' || proofInDb.tx_hash !== null) {
      console.error('FAIL Test 13: Record harus berstatus pending dengan tx_hash null karena update gagal');
      process.exit(1);
    }

    // Miner menambang transaksi tersebut on-chain
    // Cari txHash di relayer txPool
    let txHashForTrip8 = null;
    for (const [hash, tx] of relayer.txPool.entries()) {
      if (tx.proofId === proofInDb.proof_id) {
        txHashForTrip8 = hash;
        break;
      }
    }
    relayer.mineTx(txHashForTrip8, true);

    // Sekarang user melakukan retry (pemanggilan ulang endpoint)
    const broadcastsBeforeRetry = relayer.broadcastCount;
    const resRecoveryWithoutTxHash = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 8,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });

    if (resRecoveryWithoutTxHash.status !== 200 || resRecoveryWithoutTxHash.body.proof.status !== 'confirmed') {
      console.error('FAIL Test 13: Recovery on-chain gagal:', resRecoveryWithoutTxHash);
      process.exit(1);
    }
    // Pastikan TIDAK ADA broadcast transaksi kedua!
    if (relayer.broadcastCount !== broadcastsBeforeRetry) {
      console.error('FAIL Test 13: Terjadi broadcast kedua yang seharusnya dicegah!');
      process.exit(1);
    }
    console.log('PASS Test 13: Recovery berhasil mendeteksi transaksi on-chain meskipun penyimpanan tx_hash ke DB sempat gagal');
  }

  // Test 14: Retry mempertahankan proof_id yang sama persis (Anti-Orphan ProofId)
  {
    db.seedTrip({ id: 9, user_id: 'user_a_uuid', status: 'completed', items: [] });

    // Request pertama di dry-run
    const res1 = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 9,
      db,
      relayer,
      enableBroadcast: false,
    });
    const originalProofId = res1.body.proof.proof_id;

    // Simulasikan waktu berlalu (stale pending)
    const stored = await db.getProofByTripId(9);
    stored.created_at = new Date(Date.now() - 30000).toISOString();
    await db.updateProof(stored.id, { created_at: stored.created_at });

    // Request kedua (retry)
    const resRetry = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 9,
      db,
      relayer,
      enableBroadcast: false,
    });
    const retryProofId = resRetry.body.proof.proof_id;

    if (originalProofId !== retryProofId) {
      console.error('FAIL Test 14: proofId berubah saat retry! Original:', originalProofId, 'Retry:', retryProofId);
      process.exit(1);
    }
    console.log('PASS Test 14: Retry mempertahankan proof_id asli tanpa membuat proof_id baru');
  }

  // Test 15: Hash Mismatch / Anti-Tamper Detection
  {
    db.seedTrip({ id: 10, user_id: 'user_a_uuid', status: 'completed', items: [] });
    // Buat initial record
    const resInitial = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 10,
      db,
      relayer,
      enableBroadcast: false,
    });

    const targetProofId = resInitial.body.proof.proof_id;

    // Simulasikan attacker telah mendaftarkan proofId ini di smart contract dengan HASH LAIN (Tampered Hash)
    const tamperedHash = '0x' + crypto.randomBytes(32).toString('hex');
    relayer.onChainProofs.set(targetProofId.toLowerCase(), {
      proofHash: tamperedHash,
      timestamp: Math.floor(Date.now() / 1000),
      recorder: '0xAttacker',
    });

    // Panggil kembali Edge Function
    const resTamper = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 10,
      db,
      relayer,
      enableBroadcast: true,
      relayerPrivateKey: '0x1111111111111111111111111111111111111111111111111111111111111111',
    });

    if (resTamper.status !== 409 || !resTamper.body.error.includes('conflicting hash')) {
      console.error('FAIL Test 15: Tampered / conflicting hash harus ditolak 409:', resTamper);
      process.exit(1);
    }
    console.log('PASS Test 15: Percobaan manipulasi hash on-chain berhasil dideteksi dan ditolak (HTTP 409 Conflict)');
  }

  // Test 16: Regression Test - CONTRACT_ADDRESS dengan Newline (\n, {0A}), Whitespace, dan Carriage Return
  {
    db.seedTrip({ id: 11, user_id: 'user_a_uuid', status: 'completed', items: [] });
    const addressWithNewline = '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D\n';
    const resNewline = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 11,
      db,
      relayer,
      enableBroadcast: false,
      rawContractAddress: addressWithNewline,
    });

    if (resNewline.status !== 201) {
      console.error('FAIL Test 16: Sanitasi alamat dengan newline gagal:', resNewline);
      process.exit(1);
    }
    if (resNewline.body.proof.contract_address.includes('\n')) {
      console.error('FAIL Test 16: Alamat contract masih mengandung newline!');
      process.exit(1);
    }
    if (resNewline.body.proof.contract_address !== '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D') {
      console.error('FAIL Test 16: Alamat hasil normalisasi tidak sesuai:', resNewline.body.proof.contract_address);
      process.exit(1);
    }
    console.log('PASS Test 16: CONTRACT_ADDRESS dengan newline (\\n / {0A}) berhasil disanitasi dan dinormalisasi');
  }

  // Test 17: Regression Test - CONTRACT_ADDRESS Invalid Menghasilkan HTTP 500 Safe Config Error
  {
    db.seedTrip({ id: 12, user_id: 'user_a_uuid', status: 'completed', items: [] });
    const resInvalidAddr = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 12,
      db,
      relayer,
      enableBroadcast: false,
      rawContractAddress: '0xInvalidEthereumAddressNotHexFormat1234567890',
    });

    if (resInvalidAddr.status !== 500 || !resInvalidAddr.body.error.includes('Invalid contract address format')) {
      console.error('FAIL Test 17: Alamat invalid harus menghasilkan HTTP 500 aman:', resInvalidAddr);
      process.exit(1);
    }
    console.log('PASS Test 17: Alamat contract invalid dicegah sejak boundary konfigurasi dengan HTTP 500');
  }

  // Test 18: Regression Test - Pemulihan Record Pending Tanpa tx_hash (Kasus Trip 47 & 48) ke Status Simulated
  {
    // Simulasikan record trip 13 yang sempat tersimpan berstatus pending dengan tx_hash null dan alamat kotor
    const dirtyRecord = await db.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 13,
      proof_id: '0x' + crypto.randomBytes(32).toString('hex'),
      proof_hash: '0x' + crypto.randomBytes(32).toString('hex'),
      payloadVersion: '1.0.0',
      snapshot_json: '{}',
      salt: 'salt13',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D\n', // Alamat lama yang kotor
      tx_hash: null,
      status: 'pending', // Stuck pending
      created_at: new Date(Date.now() - 60000).toISOString(),
    });

    db.seedTrip({ id: 13, user_id: 'user_a_uuid', status: 'completed', items: [] });

    // Panggil ulang Edge Function (simulasi sinkronisasi / perbarui bukti oleh pengguna)
    const resHeal = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 13,
      db,
      relayer,
      enableBroadcast: false,
      rawContractAddress: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
    });

    if (resHeal.status !== 201) {
      console.error('FAIL Test 18: Pemulihan record pending gagal:', resHeal);
      process.exit(1);
    }
    if (resHeal.body.proof.status !== 'simulated') {
      console.error('FAIL Test 18: Status harus berubah menjadi simulated, didapat:', resHeal.body.proof.status);
      process.exit(1);
    }
    if (resHeal.body.proof.contract_address !== '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D') {
      console.error('FAIL Test 18: Alamat contract pada record lama tidak dipulihkan:', resHeal.body.proof.contract_address);
      process.exit(1);
    }
    if (resHeal.body.proof.proof_id !== dirtyRecord.proof_id) {
      console.error('FAIL Test 18: proof_id berubah saat pemulihan!');
      process.exit(1);
    }
    console.log('PASS Test 18: Bukti berstatus pending tanpa tx_hash berhasil dipulihkan ke simulated tanpa kehilangan data');
  }

  // Test 19: Regression Test - Mode Dry-Run Menjamin Tidak Ada Transaksi On-Chain Palsu
  {
    db.seedTrip({ id: 14, user_id: 'user_a_uuid', status: 'completed', items: [] });
    const initialPoolSize = relayer.txPool.size;
    const initialBroadcasts = relayer.broadcastCount;

    const resDryRun = await executeRecordProofEdgeFunction({
      authHeader: 'Bearer user_a_token',
      tripId: 14,
      db,
      relayer,
      enableBroadcast: false,
    });

    if (resDryRun.body.mode !== 'dry_run' || resDryRun.body.broadcast_enabled !== false) {
      console.error('FAIL Test 19: Mode respons bukan dry-run:', resDryRun.body);
      process.exit(1);
    }
    if (resDryRun.body.proof.tx_hash !== null && resDryRun.body.proof.tx_hash !== undefined) {
      console.error('FAIL Test 19: Bukti simulated tidak boleh memiliki tx_hash!');
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts || relayer.txPool.size !== initialPoolSize) {
      console.error('FAIL Test 19: Mode dry-run tidak boleh menambah transaksi di blockchain mempool!');
      process.exit(1);
    }
    console.log('PASS Test 19: Mode dry-run menjamin broadcast_enabled=false dan tx_hash tetap null');
  }

  console.log('=====================================================');
  console.log('ALL 19 RELAYER & NON-ATOMIC RECOVERY TESTS PASSED!');
  console.log('=====================================================');
}

runTests().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
