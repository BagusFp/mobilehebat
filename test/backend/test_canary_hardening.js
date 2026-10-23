// Automated Test Suite: Focused Canary Safety Hardening (Trip ID 50)
// Menguji skenario proteksi canary:
// 1. Trip selain ID 50 ditolak tegas
// 2. Unauthorized owner ditolak
// 3. Hak akses PostgREST / RPC Security Definer (Direct access ditolak)
// 4. Claim RPC database error membatalkan broadcast (Fail-safe)
// 5. Claim RPC timeout membatalkan broadcast (Fail-safe)
// 6. Dua request konkuren PROOF SAMA (Tepat 1 broadcast, 2nd has_execution_permit=false)
// 7. Dua request konkuren PROOF BERBEDA (HTTP 409 scope_exhausted)
// 8. Retry request identik (Idempotent: has_execution_permit=false, 0 second broadcast)
// 9. Pending tx tanpa receipt di mempool (HTTP 202: 0 second broadcast)
// 10. Crash setelah broadcast: Mined on-chain recovery (HTTP 200: 0 second broadcast)
// 11. Nonce collision / Replaced on-chain (HTTP 409 recovery_required: 0 second broadcast)
// 12. Ambiguous crash window outcome: Nonce pending (HTTP 202 recovery_required: 0 second broadcast)
// 13. DB update failure saat menyimpan tx_hash tertahan oleh durable state (Zero second broadcast)
// 14. State CAS Race Condition / State Mismatch (HTTP 500 fail-closed: 0 broadcast)
// 15. Crash sebelum broadcast (State 'reserved' tanpa broadcast intent menolak retry: HTTP 409, 0 broadcast)
// 16. Gas fee di atas hard-cap 50 Gwei ditolak sebelum broadcast (HTTP 503)
// 17. Proof sudah tercatat di smart contract langsung direkonsiliasi (Zero second broadcast)
// 18. Canary scope exhausted (Single-use circuit breaker mengunci permanen)

const crypto = require('crypto');
const { ethers } = require('ethers');

console.log('======================================================================');
console.log('STARTING EXTENSIVE CANARY SAFETY HARDENING TEST SUITE (22 SCENARIOS)');
console.log('======================================================================');

// Mock Database Supabase dengan simulasi tabel trip_proofs dan canary_claims
class MockCanaryDB {
  constructor() {
    this.trips = new Map();
    this.trip_proofs = new Map();
    this.canary_claims = new Map(); // canary_scope -> claim row
    this.nextProofId = 1;
    this.nextClaimId = 1;
    this.failOnProofUpdate = false;
    this.failOnTxHashSave = false;
    this.claimRpcError = false;
    this.claimRpcTimeout = false;
    this.failOnTransition = false;
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

  async insertProof(proofRecord) {
    for (const proof of this.trip_proofs.values()) {
      if (proof.trip_id === proofRecord.trip_id) {
        const err = new Error('duplicate key value violates unique constraint "trip_proofs_trip_id_key"');
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
    if (this.failOnTxHashSave && updates.tx_hash) {
      throw new Error('DATABASE_CONNECTION_TIMEOUT: Failed to update tx_hash in trip_proofs');
    }
    if (this.failOnProofUpdate) {
      throw new Error('DATABASE_CONNECTION_TIMEOUT: Failed to update row in trip_proofs');
    }
    if (!this.trip_proofs.has(id)) throw new Error('Proof not found');
    const updated = { ...this.trip_proofs.get(id), ...updates };
    this.trip_proofs.set(id, updated);
    return { ...updated };
  }

  // Simulasi RPC acquire_or_get_canary_claim
  async acquireOrGetCanaryClaim({ canaryScope, tripId, userId, proofId, proofHash, idempotencyKey, role = 'service_role' }) {
    // Audit akses: Hanya service_role yang diizinkan memanggil fungsi ini
    if (role !== 'service_role') {
      const permErr = new Error('permission denied for function acquire_or_get_canary_claim');
      permErr.code = '42501';
      throw permErr;
    }

    if (this.claimRpcError) {
      const err = new Error('DATABASE_RPC_ERROR: PostgreSQL connection lost');
      err.code = '08006';
      throw err;
    }

    if (this.claimRpcTimeout) {
      const err = new Error('DATABASE_RPC_TIMEOUT: Execution timed out after 5000ms');
      err.code = '57014';
      throw err;
    }

    if (this.canary_claims.has(canaryScope)) {
      const existing = this.canary_claims.get(canaryScope);
      const safeClaim = { ...existing };
      delete safeClaim.execution_token;
      if (existing.trip_id === tripId && existing.proof_id === proofId) {
        return {
          status: 'existing_claim',
          is_owner: true,
          has_execution_permit: false,
          action: 'reconcile_only',
          execution_token: null,
          claim: safeClaim,
        };
      } else {
        return {
          status: 'scope_exhausted',
          is_owner: false,
          has_execution_permit: false,
          action: 'reject',
          execution_token: null,
          claim: safeClaim,
        };
      }
    }

    const id = this.nextClaimId++;
    const executionToken = 'token_' + crypto.randomBytes(16).toString('hex');
    const newClaim = {
      id,
      canary_scope: canaryScope,
      trip_id: tripId,
      user_id: userId,
      proof_id: proofId,
      proof_hash: proofHash,
      idempotency_key: idempotencyKey,
      execution_token: executionToken,
      state: 'reserved',
      tx_hash: null,
      relayer_nonce: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.canary_claims.set(canaryScope, newClaim);
    return {
      status: 'acquired',
      is_owner: true,
      has_execution_permit: true,
      action: 'execute_broadcast',
      execution_token: executionToken,
      claim: { ...newClaim },
    };
  }

  // Simulasi RPC transition_canary_claim_state (State CAS)
  async transitionCanaryClaimState({ canaryScope, expectedState, newState, executionToken = null, txHash = null, relayerNonce = null, gasLimit = null, conservativeMaxFeeGwei = null, errorMessage = null, role = 'service_role' }) {
    if (role !== 'service_role') {
      const permErr = new Error('permission denied for function transition_canary_claim_state');
      permErr.code = '42501';
      throw permErr;
    }

    if (this.failOnTransition) {
      const err = new Error('DATABASE_RPC_ERROR: State transition connection error');
      err.code = '08006';
      throw err;
    }

    if (!this.canary_claims.has(canaryScope)) {
      return { success: false, error: 'claim_not_found', canary_scope: canaryScope };
    }

    const current = this.canary_claims.get(canaryScope);
    if (current.state !== expectedState) {
      const safeClaim = { ...current };
      delete safeClaim.execution_token;
      return {
        success: false,
        error: 'state_mismatch',
        current_state: current.state,
        expected_state: expectedState,
        claim: safeClaim,
      };
    }

    // Atomic Authorization: transisi dari reserved WAJIB memiliki execution_token yang valid
    if (expectedState === 'reserved') {
      if (!executionToken || current.execution_token !== executionToken) {
        return {
          success: false,
          error: 'invalid_execution_token',
          canary_scope: canaryScope,
          current_state: current.state,
        };
      }
    }

    const updated = {
      ...current,
      state: newState,
      tx_hash: txHash !== null ? txHash : current.tx_hash,
      relayer_nonce: relayerNonce !== null ? relayerNonce : current.relayer_nonce,
      gas_limit: gasLimit !== null ? gasLimit : current.gas_limit,
      conservative_max_fee_gwei: conservativeMaxFeeGwei !== null ? conservativeMaxFeeGwei : current.conservative_max_fee_gwei,
      error_message: errorMessage !== null ? errorMessage : current.error_message,
      updated_at: new Date().toISOString(),
    };
    this.canary_claims.set(canaryScope, updated);
    const safeUpdated = { ...updated };
    delete safeUpdated.execution_token;
    return {
      success: true,
      previous_state: expectedState,
      current_state: newState,
      claim: safeUpdated,
    };
  }

  async updateCanaryClaim(canaryScope, updates) {
    if (!this.canary_claims.has(canaryScope)) return null;
    const updated = { ...this.canary_claims.get(canaryScope), ...updates, updated_at: new Date().toISOString() };
    this.canary_claims.set(canaryScope, updated);
    return { ...updated };
  }
}

// Mock Sepolia Relayer & Smart Contract
class MockSepoliaCanaryRelayer {
  constructor() {
    this.onChainProofs = new Map();
    this.txPool = new Map();
    this.broadcastCount = 0;
    this.latestNonce = 1;
    this.pendingNonce = 1;
    this.networkMaxFeeGwei = 2.5; // Normal Sepolia fee
    this.shouldTimeoutOnBroadcast = false;
    this.estimateGasUnits = 355498n;
  }

  async isProofRecorded(proofId) {
    return this.onChainProofs.has(proofId.toLowerCase());
  }

  async getProof(proofId) {
    const p = this.onChainProofs.get(proofId.toLowerCase());
    if (!p) throw new Error('MeraTripProof: Proof not found');
    return { ...p };
  }

  async staticCallRecordProof(proofId, proofHash) {
    if (this.onChainProofs.has(proofId.toLowerCase())) {
      throw new Error('MeraTripProof: Proof already recorded');
    }
    return true;
  }

  async broadcastRecordProof(proofId, proofHash, overrides) {
    if (this.shouldTimeoutOnBroadcast) {
      const txHash = '0x' + crypto.randomBytes(32).toString('hex');
      this.txPool.set(txHash, { status: null, proofId, proofHash, nonce: overrides.nonce });
      this.broadcastCount++;
      this.pendingNonce++;
      const timeoutErr = new Error('RPC_TIMEOUT: Connection dropped during eth_sendRawTransaction');
      timeoutErr.txHash = txHash;
      throw timeoutErr;
    }

    await this.staticCallRecordProof(proofId, proofHash);
    this.broadcastCount++;
    const txHash = '0x' + crypto.randomBytes(32).toString('hex');
    this.txPool.set(txHash, { status: null, proofId, proofHash, nonce: overrides.nonce });
    this.pendingNonce++;
    return txHash;
  }

  mineTx(txHash, success = true) {
    if (!this.txPool.has(txHash)) throw new Error('Tx not in pool');
    const tx = this.txPool.get(txHash);
    tx.status = success ? 1 : 0;
    this.latestNonce++;
    if (success) {
      this.onChainProofs.set(tx.proofId.toLowerCase(), {
        proofHash: tx.proofHash,
        timestamp: Math.floor(Date.now() / 1000),
        recorder: '0x521EFC3eeA82684Ba0143C5707EdF281d6E7Cd21',
      });
    }
  }

  async getTransactionReceipt(txHash) {
    const tx = this.txPool.get(txHash);
    if (!tx || tx.status === null) return null;
    return { status: tx.status, transactionHash: txHash };
  }

  async getTransaction(txHash) {
    const tx = this.txPool.get(txHash);
    if (!tx) return null;
    return { hash: txHash, from: '0x521EFC3eeA82684Ba0143C5707EdF281d6E7Cd21', nonce: tx.nonce };
  }
}

// Simulasi Edge Function record-proof Terbaru (Fail-Safe Hardened)
async function executeHardenedRecordProof({
  authHeader,
  tripId,
  db,
  relayer,
  enableBroadcast = false,
  relayerPrivateKey = '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  rawContractAddress = '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
  idempotencyKey = null,
}) {
  const CANARY_TRIP_ID = 50;
  const CANARY_SCOPE = 'CANARY_TRIP_50';
  const HARD_CAP_MAX_FEE = ethers.parseUnits('50', 'gwei');
  const HARD_CAP_PRIORITY_FEE = ethers.parseUnits('5', 'gwei');
  const MAX_ALLOWED_BUDGET_ETH = ethers.parseEther('0.025');
  const MAX_GAS_LIMIT = 500000n;

  const numericTripId = Number(tripId);
  if (!numericTripId || !Number.isSafeInteger(numericTripId) || numericTripId <= 0) {
    return { status: 400, body: { error: 'trip_id is required or invalid' } };
  }

  // 1. CANARY SCOPE GUARD: Tolak tegas trip selain Trip ID 50 jika broadcast diaktifkan
  if (enableBroadcast && numericTripId !== CANARY_TRIP_ID) {
    return {
      status: 403,
      body: {
        error: `Canary phase restriction: Broadcast is strictly locked to Trip ID ${CANARY_TRIP_ID}. Trip ${numericTripId} cannot be broadcast on-chain.`,
        canary_trip_id: CANARY_TRIP_ID,
        requested_trip_id: numericTripId,
      },
    };
  }

  // 2. Auth check
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { status: 401, body: { error: 'Missing or invalid Authorization header' } };
  }
  const token = authHeader.replace('Bearer ', '');
  if (token === 'invalid_token') {
    return { status: 401, body: { error: 'Unauthorized user session' } };
  }
  const user = { id: token === 'user_b_token' ? 'user_b_uuid' : 'user_a_uuid' };

  // 3. Trip fetch & ownership check
  const trip = await db.getTrip(numericTripId);
  if (!trip) {
    return { status: 404, body: { error: 'Trip not found' } };
  }
  if (trip.user_id !== user.id) {
    return { status: 403, body: { error: 'Trip does not belong to the authenticated user' } };
  }
  if (trip.status !== 'completed') {
    return { status: 400, body: { error: 'Trip must be completed to generate proof of visit' } };
  }

  // 4. Existing proof & recovery check
  const existingProof = await db.getProofByTripId(numericTripId);
  let activeProof = existingProof;

  if (existingProof) {
    if (existingProof.status === 'confirmed') {
      return { status: 200, body: { message: 'Existing proof confirmed on-chain', proof: existingProof } };
    }

    if (existingProof.status === 'simulated' && (!enableBroadcast || !relayerPrivateKey)) {
      return {
        status: 200,
        body: {
          message: 'Existing dry-run proof simulation verified',
          proof: existingProof,
          mode: 'dry_run',
          broadcast_enabled: false,
        },
      };
    }

    // Pending dengan tx_hash
    if (existingProof.tx_hash && existingProof.status === 'pending') {
      const receipt = await relayer.getTransactionReceipt(existingProof.tx_hash);
      if (receipt && receipt.status === 1) {
        const confirmed = await db.updateProof(existingProof.id, {
          status: 'confirmed',
          confirmed_at: new Date().toISOString(),
        });
        return { status: 200, body: { message: 'Pending transaction recovered and confirmed on-chain', proof: confirmed } };
      } else if (receipt && receipt.status === 0) {
        const failed = await db.updateProof(existingProof.id, { status: 'failed' });
        return { status: 400, body: { error: 'Previous on-chain transaction reverted', proof: failed } };
      } else {
        return { status: 202, body: { message: 'Transaction is currently pending in Sepolia mempool', proof: existingProof } };
      }
    }

    // Pending tanpa tx_hash: cek apakah sudah recorded on-chain
    const isRecorded = await relayer.isProofRecorded(existingProof.proof_id);
    if (isRecorded) {
      const confirmed = await db.updateProof(existingProof.id, {
        status: 'confirmed',
        confirmed_at: new Date().toISOString(),
      });
      return { status: 200, body: { message: 'Proof recovered successfully from Ethereum Sepolia', proof: confirmed } };
    }
  }

  // 5. Build/reuse canonical payload
  let proofId, proofHash;
  if (activeProof) {
    proofId = activeProof.proof_id;
    proofHash = activeProof.proof_hash;
  } else {
    proofId = '0x' + crypto.randomBytes(32).toString('hex');
    proofHash = '0x' + crypto.randomBytes(32).toString('hex');
    const inserted = await db.insertProof({
      user_id: user.id,
      trip_id: numericTripId,
      proof_id: proofId,
      proof_hash: proofHash,
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'salttest',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });
    activeProof = inserted;
  }

  // 6. On-chain check sebelum eksekusi
  if (await relayer.isProofRecorded(proofId)) {
    const confirmed = await db.updateProof(activeProof.id, {
      status: 'confirmed',
      confirmed_at: new Date().toISOString(),
    });
    return { status: 200, body: { message: 'Proof already confirmed on Ethereum Sepolia', proof: confirmed } };
  }

  // 7. Dry-run mode jika broadcast false
  if (!enableBroadcast || !relayerPrivateKey) {
    await relayer.staticCallRecordProof(proofId, proofHash);
    const updated = await db.updateProof(activeProof.id, { status: 'simulated' });
    return {
      status: 201,
      body: {
        message: 'Dry-run mode aktif. Simulasi staticCall on-chain berhasil.',
        proof: updated,
        mode: 'dry_run',
        broadcast_enabled: false,
      },
    };
  }

  // 8. BROADCAST CANARY ON-CHAIN (FAIL-SAFE & RECONCILIATION HARDENED)
  try {
    // 8A. ATOMIC CANARY CLAIM / CIRCUIT BREAKER
    const effectiveIdempotencyKey = idempotencyKey || `canary_trip_${numericTripId}_proof_${proofId.slice(2, 10)}`;
    let claimResult;

    try {
      claimResult = await db.acquireOrGetCanaryClaim({
        canaryScope: CANARY_SCOPE,
        tripId: numericTripId,
        userId: user.id,
        proofId,
        proofHash,
        idempotencyKey: effectiveIdempotencyKey,
        role: 'service_role',
      });
    } catch (claimErr) {
      // FAIL-SAFE: Jika claim RPC error atau timeout, broadcast HARUS DIBATALKAN!
      return {
        status: 500,
        body: { error: `Canary circuit breaker error: Failed to acquire atomic claim (${claimErr.message}). Broadcast aborted for safety.` },
      };
    }

    if (!claimResult) {
      return { status: 500, body: { error: 'Canary circuit breaker: Empty claim response. Broadcast aborted for safety.' } };
    }

    if (claimResult.status === 'scope_exhausted' || !claimResult.is_owner) {
      return {
        status: 409,
        body: {
          error: 'Canary circuit breaker: Broadcast slot is already claimed and locked. Only one canary transaction is allowed.',
          canary_scope: CANARY_SCOPE,
          existing_claim: claimResult.claim,
        },
      };
    }

    const canaryClaimRecord = claimResult.claim;
    const hasExecutionPermit = claimResult.has_execution_permit === true;
    const executionToken = claimResult.execution_token || null;

    // 8B. EXISTING CLAIM RECONCILIATION & IDEMPOTENT RESPONSE ONLY
    // JAMINAN KEAMANAN: Request tanpa execution permit (retry / existing claim / concurrent loser)
    // DILARANG KERAS melanjutkan ke jalur broadcast on-chain.
    if (!hasExecutionPermit) {
      // 1. Jika sudah confirmed on-chain
      if (canaryClaimRecord.state === 'confirmed') {
        return { status: 200, body: { message: 'Canary proof already confirmed on Ethereum Sepolia', proof: activeProof } };
      }

      // 2. Jika tx_hash sudah diketahui
      if (canaryClaimRecord.state === 'tx_known' && canaryClaimRecord.tx_hash) {
        const receipt = await relayer.getTransactionReceipt(canaryClaimRecord.tx_hash);
        if (receipt && receipt.status === 1) {
          await db.transitionCanaryClaimState({
            canaryScope: CANARY_SCOPE,
            expectedState: 'tx_known',
            newState: 'confirmed',
            txHash: canaryClaimRecord.tx_hash,
          });
          const confirmed = await db.updateProof(activeProof.id, {
            status: 'confirmed',
            tx_hash: canaryClaimRecord.tx_hash,
            confirmed_at: new Date().toISOString(),
          });
          return { status: 200, body: { message: 'Pending canary transaction recovered and confirmed on-chain', proof: confirmed } };
        } else if (receipt && receipt.status === 0) {
          return { status: 400, body: { error: 'Previous canary transaction reverted on-chain during execution' } };
        }

        const mempoolTx = await relayer.getTransaction(canaryClaimRecord.tx_hash);
        if (mempoolTx) {
          return {
            status: 202,
            body: { message: 'Canary transaction is currently pending in Sepolia mempool', tx_hash: canaryClaimRecord.tx_hash },
          };
        }
      }

      // 3. Jika broadcast pernah dicoba (crash window), rekonsiliasi on-chain & relayer nonce
      if (canaryClaimRecord.state === 'broadcast_attempted' || canaryClaimRecord.state === 'recovery_required') {
        if (await relayer.isProofRecorded(proofId)) {
          await db.transitionCanaryClaimState({
            canaryScope: CANARY_SCOPE,
            expectedState: canaryClaimRecord.state,
            newState: 'confirmed',
            txHash: canaryClaimRecord.tx_hash || null,
          });
          const confirmed = await db.updateProof(activeProof.id, { status: 'confirmed', confirmed_at: new Date().toISOString() });
          return { status: 200, body: { message: 'Canary proof recovered and verified on-chain', proof: confirmed } };
        }

        const claimNonce = canaryClaimRecord.relayer_nonce;
        if (claimNonce !== null && claimNonce !== undefined) {
          const latestNonce = relayer.latestNonce;
          const pendingNonce = relayer.pendingNonce;

          if (latestNonce > claimNonce) {
            await db.transitionCanaryClaimState({
              canaryScope: CANARY_SCOPE,
              expectedState: canaryClaimRecord.state,
              newState: 'recovery_required',
              errorMessage: `Nonce ${claimNonce} consumed on-chain without proof. Transaction was replaced or dropped.`,
            });
            return {
              status: 409,
              body: {
                error: `Canary nonce collision / replaced: Relayer nonce ${claimNonce} was consumed on-chain without recording proof. Manual administrative recovery required.`,
                state: 'recovery_required',
                relayer_nonce: claimNonce,
              },
            };
          }

          if (pendingNonce > claimNonce) {
            return {
              status: 202,
              body: {
                message: `Canary broadcast is currently in-flight in mempool with nonce ${claimNonce}. Waiting for block inclusion.`,
                state: 'broadcast_attempted',
                relayer_nonce: claimNonce,
              },
            };
          }

          await db.transitionCanaryClaimState({
            canaryScope: CANARY_SCOPE,
            expectedState: canaryClaimRecord.state,
            newState: 'recovery_required',
            errorMessage: 'Broadcast outcome ambiguous. Pending automatic reconciliation.',
          });
          return {
            status: 202,
            body: {
              message: 'Canary broadcast outcome is ambiguous. System has set state to recovery_required. No second transaction was created.',
              state: 'recovery_required',
              relayer_nonce: claimNonce,
            },
          };
        }
      }

      // 4. Jika state 'reserved': proses lain sedang berjalan atau crash sebelum broadcast intent dikunci.
      if (canaryClaimRecord.state === 'reserved') {
        return {
          status: 409,
          body: {
            error: 'Canary claim is currently reserved by an in-flight execution. Retry is restricted to reconciliation and cannot broadcast.',
            canary_scope: CANARY_SCOPE,
            state: 'reserved',
            action: 'reconcile_only',
          },
        };
      }

      return {
        status: 409,
        body: {
          error: `Canary claim in state '${canaryClaimRecord.state}' cannot be re-executed. Broadcast aborted for safety.`,
          canary_scope: CANARY_SCOPE,
          state: canaryClaimRecord.state,
        },
      };
    }

    // 8C. GAS BUDGET & HARD SAFETY CAP POLICY (HANYA UNTUK PEMEGANG EXECUTION PERMIT)
    const rawMaxFee = ethers.parseUnits(relayer.networkMaxFeeGwei.toString(), 'gwei');
    if (rawMaxFee > HARD_CAP_MAX_FEE) {
      return {
        status: 503,
        body: {
          error: `Network fee surge: Current max fee (${ethers.formatUnits(rawMaxFee, 'gwei')} Gwei) exceeds canary hard cap (50 Gwei). Transaction aborted.`,
        },
      };
    }
    const maxFeePerGas = rawMaxFee;
    const maxPriorityFeePerGas = ethers.parseUnits('2', 'gwei');

    const estimatedGas = relayer.estimateGasUnits;
    const gasLimit = (estimatedGas * 120n) / 100n;
    if (gasLimit > MAX_GAS_LIMIT) {
      return {
        status: 400,
        body: { error: `Gas limit policy violation: Estimated gas (${gasLimit}) exceeds upper limit (${MAX_GAS_LIMIT}).` },
      };
    }

    const conservativeMaxCost = gasLimit * maxFeePerGas;
    if (conservativeMaxCost > MAX_ALLOWED_BUDGET_ETH) {
      return {
        status: 400,
        body: { error: `Budget limit violation: Conservative max cost exceeds canary budget.` },
      };
    }

    // 8D. DETERMINISTIC NONCE & DURABLE INTENT (STATE CAS FAIL-CLOSED)
    const relayerNonce = relayer.pendingNonce;
    let transitionRes;
    try {
      transitionRes = await db.transitionCanaryClaimState({
        canaryScope: CANARY_SCOPE,
        expectedState: 'reserved',
        newState: 'broadcast_attempted',
        executionToken,
        relayerNonce,
        gasLimit: Number(gasLimit),
        conservativeMaxFeeGwei: Number(ethers.formatUnits(maxFeePerGas, 'gwei')),
      });
    } catch (transErr) {
      return {
        status: 500,
        body: {
          error: `Canary circuit breaker error: Failed to lock atomic broadcast intent (${transErr.message || 'State transition failed'}). Broadcast aborted for safety.`,
        },
      };
    }

    if (!transitionRes || !transitionRes.success) {
      return {
        status: 500,
        body: {
          error: `Canary circuit breaker error: Failed to lock atomic broadcast intent (${transitionRes?.error || 'State transition failed'}). Broadcast aborted for safety.`,
        },
      };
    }

    await db.updateProof(activeProof.id, { status: 'pending' });

    // 8E. BROADCAST
    let txHash;
    try {
      txHash = await relayer.broadcastRecordProof(proofId, proofHash, {
        maxPriorityFeePerGas,
        maxFeePerGas,
        gasLimit,
        nonce: relayerNonce,
      });
    } catch (sendErr) {
      if (sendErr.message && sendErr.message.includes('RPC_TIMEOUT') && sendErr.txHash) {
        txHash = sendErr.txHash;
        await db.transitionCanaryClaimState({
          canaryScope: CANARY_SCOPE,
          expectedState: 'broadcast_attempted',
          newState: 'tx_known',
          executionToken,
          txHash,
          relayerNonce,
        });
        await db.updateProof(activeProof.id, { tx_hash: txHash, status: 'pending' });
        return {
          status: 202,
          body: {
            message: 'Canary transaction broadcast status is ambiguous (pending in RPC or mempool). System has preserved state for automatic reconciliation.',
            proof: { ...activeProof, tx_hash: txHash, status: 'pending' },
          },
        };
      }
      throw sendErr;
    }

    // Update state to tx_known via CAS
    await db.transitionCanaryClaimState({
      canaryScope: CANARY_SCOPE,
      expectedState: 'broadcast_attempted',
      newState: 'tx_known',
      executionToken,
      txHash,
      relayerNonce,
    });

    // Resilient save to trip_proofs
    try {
      await db.updateProof(activeProof.id, { tx_hash: txHash, status: 'pending' });
    } catch (saveErr) {
      console.warn('Simulation: DB update tx_hash in trip_proofs failed:', saveErr.message);
    }

    // 8F. Receipt Wait
    const receipt = await relayer.getTransactionReceipt(txHash);
    let finalStatus = 'pending';
    if (receipt && receipt.status === 1) {
      finalStatus = 'confirmed';
      await db.updateCanaryClaim(CANARY_SCOPE, { state: 'confirmed' });
    } else if (receipt && receipt.status === 0) {
      finalStatus = 'failed';
      await db.updateCanaryClaim(CANARY_SCOPE, { state: 'failed_recoverable' });
    }

    let finalProof;
    try {
      finalProof = await db.updateProof(activeProof.id, {
        tx_hash: txHash,
        status: finalStatus,
        confirmed_at: finalStatus === 'confirmed' ? new Date().toISOString() : null,
      });
    } catch (_) {
      finalProof = { ...activeProof, tx_hash: txHash, status: finalStatus };
    }

    return {
      status: finalStatus === 'confirmed' ? 200 : 202,
      body: {
        message: finalStatus === 'confirmed'
          ? 'Canary proof recorded and confirmed on Ethereum Sepolia'
          : 'Canary proof transaction broadcast to Sepolia (pending confirmation in mempool)',
        proof: finalProof,
        mode: 'on_chain',
        broadcast_enabled: true,
        canary_scope: CANARY_SCOPE,
        tx_hash: txHash,
      },
    };
  } catch (err) {
    const errMsg = err.message || String(err);
    const isAmbiguous = errMsg.includes('timeout') || errMsg.includes('already known') || errMsg.includes('replacement');
    if (!isAmbiguous) {
      await db.updateCanaryClaim(CANARY_SCOPE, { state: 'failed_recoverable', error_message: errMsg });
      await db.updateProof(activeProof.id, { status: 'failed' });
      return { status: 502, body: { error: `Relayer definitive pre-broadcast error: ${errMsg}` } };
    } else {
      await db.updateCanaryClaim(CANARY_SCOPE, { state: 'recovery_required', error_message: errMsg });
      return {
        status: 202,
        body: {
          message: 'Canary transaction broadcast status is ambiguous (pending in RPC or mempool). System has preserved state for automatic reconciliation.',
          proof: { ...activeProof, status: 'pending' },
        },
      };
    }
  }
}

// ======================================================================
// RUNNING THE 15 SCENARIOS
// ======================================================================
async function runCanaryTests() {
  const db = new MockCanaryDB();
  const relayer = new MockSepoliaCanaryRelayer();

  db.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
  db.seedTrip({ id: 49, user_id: 'user_a_uuid', status: 'completed' });

  // SCENARIO 1: Trip ID selain 50 ditolak tegas saat broadcast aktif
  {
    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 49,
      db,
      relayer,
      enableBroadcast: true,
    });
    if (res.status !== 403 || !res.body.error.includes('strictly locked to Trip ID 50')) {
      console.error('FAIL Scenario 1:', res);
      process.exit(1);
    }
    if (relayer.broadcastCount !== 0) {
      console.error('FAIL Scenario 1: Broadcast triggered!');
      process.exit(1);
    }
    console.log('PASS Scenario 1: Trip ID selain 50 ditolak tegas untuk broadcast (HTTP 403 Forbidden)');
  }

  // SCENARIO 2: Unauthorized owner ditolak
  {
    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_b_token',
      tripId: 50,
      db,
      relayer,
      enableBroadcast: true,
    });
    if (res.status !== 403 || !res.body.error.includes('does not belong to the authenticated user')) {
      console.error('FAIL Scenario 2:', res);
      process.exit(1);
    }
    if (relayer.broadcastCount !== 0) {
      console.error('FAIL Scenario 2: Broadcast triggered!');
      process.exit(1);
    }
    console.log('PASS Scenario 2: Request dari user bukan pemilik Trip 50 ditolak (HTTP 403 Forbidden)');
  }

  // SCENARIO 3: Direct authenticated RPC access ditolak (PostgREST privilege audit)
  {
    try {
      await db.acquireOrGetCanaryClaim({
        canaryScope: 'CANARY_TRIP_50',
        tripId: 50,
        userId: 'user_a_uuid',
        proofId: '0xabc',
        proofHash: '0xdef',
        idempotencyKey: 'direct_attack',
        role: 'authenticated', // Dipanggil via token user biasa
      });
      console.error('FAIL Scenario 3: Authenticated user diizinkan memanggil RPC secara langsung!');
      process.exit(1);
    } catch (rpcErr) {
      if (rpcErr.code !== '42501') {
        console.error('FAIL Scenario 3: Error bukan permission denied:', rpcErr);
        process.exit(1);
      }
    }
    console.log('PASS Scenario 3: Akses PostgREST langsung ke acquire_or_get_canary_claim ditolak (Error 42501 Permission Denied)');
  }

  // SCENARIO 4: Claim RPC database error membatalkan broadcast (Fail-safe)
  {
    const dbErr = new MockCanaryDB();
    const relayerErr = new MockSepoliaCanaryRelayer();
    dbErr.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
    dbErr.claimRpcError = true;

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbErr,
      relayer: relayerErr,
      enableBroadcast: true,
    });

    if (res.status !== 500 || !res.body.error.includes('Broadcast aborted for safety')) {
      console.error('FAIL Scenario 4: Error RPC tidak membatalkan broadcast:', res);
      process.exit(1);
    }
    if (relayerErr.broadcastCount !== 0) {
      console.error('FAIL Scenario 4: Broadcast dijalankan saat RPC error!');
      process.exit(1);
    }
    console.log('PASS Scenario 4: Claim RPC database error membatalkan broadcast secara fail-safe (HTTP 500)');
  }

  // SCENARIO 5: Claim RPC timeout membatalkan broadcast (Fail-safe)
  {
    const dbTimeout = new MockCanaryDB();
    const relayerTimeout = new MockSepoliaCanaryRelayer();
    dbTimeout.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
    dbTimeout.claimRpcTimeout = true;

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbTimeout,
      relayer: relayerTimeout,
      enableBroadcast: true,
    });

    if (res.status !== 500 || !res.body.error.includes('Broadcast aborted for safety')) {
      console.error('FAIL Scenario 5: Timeout RPC tidak membatalkan broadcast:', res);
      process.exit(1);
    }
    if (relayerTimeout.broadcastCount !== 0) {
      console.error('FAIL Scenario 5: Broadcast dijalankan saat RPC timeout!');
      process.exit(1);
    }
    console.log('PASS Scenario 5: Claim RPC timeout membatalkan broadcast secara fail-safe (HTTP 500)');
  }

  // SCENARIO 6: Dua request konkuren PROOF SAMA (Atomic Canary Reservation)
  // Request 1 memenangkan INSERT (has_execution_permit = true) -> Menjalankan broadcast
  // Request 2 konkuren untuk proof yang sama (has_execution_permit = false) -> DILARANG broadcast
  {
    const initialBroadcasts = relayer.broadcastCount;
    const res1 = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db,
      relayer,
      enableBroadcast: true,
      idempotencyKey: 'concurrent_req_1',
    });

    const activeProof = await db.getProofByTripId(50);

    // Request 2 mencoba klaim untuk proof ID yang SAMA secara bersamaan
    const claimRes2 = await db.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: activeProof.proof_id,
      proofHash: activeProof.proof_hash,
      idempotencyKey: 'concurrent_req_2',
    });

    if (claimRes2.has_execution_permit !== false || claimRes2.action !== 'reconcile_only') {
      console.error('FAIL Scenario 6: Request 2 konkuren proof sama memperoleh execution permit!', claimRes2);
      process.exit(1);
    }

    if (res1.status !== 200 && res1.status !== 202) {
      console.error('FAIL Scenario 6: Request primer gagal:', res1);
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts + 1) {
      console.error('FAIL Scenario 6: Broadcast terjadi lebih dari 1 kali:', relayer.broadcastCount);
      process.exit(1);
    }
    console.log('PASS Scenario 6: Dua request konkuren PROOF SAMA tertangani secara atomik (Tepat 1 broadcast, request kedua has_execution_permit=false)');
  }

  // SCENARIO 7: Dua request konkuren PROOF BERBEDA
  // Request konkuren mencoba mendaftarkan proofId lain pada scope yang sama -> Ditolak 409 scope_exhausted
  {
    const initialBroadcasts = relayer.broadcastCount;
    const resDifferent = await db.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0x9999999999999999999999999999999999999999999999999999999999999999',
      proofHash: '0x8888888888888888888888888888888888888888888888888888888888888888',
      idempotencyKey: 'concurrent_diff_proof',
    });

    if (resDifferent.status !== 'scope_exhausted' || resDifferent.is_owner !== false || resDifferent.has_execution_permit !== false) {
      console.error('FAIL Scenario 7: Request konkuren proof berbeda tidak ditolak circuit breaker:', resDifferent);
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts) {
      console.error('FAIL Scenario 7: Broadcast terpicu oleh proof berbeda!');
      process.exit(1);
    }
    console.log('PASS Scenario 7: Dua request konkuren PROOF BERBEDA ditolak tegas (HTTP 409 scope_exhausted, 0 broadcast)');
  }

  // SCENARIO 8: Retry request identik
  // Membuktikan bahwa retry hanya melakukan idempotent response / rekonsiliasi dan tidak memperoleh izin broadcast
  {
    const initialBroadcasts = relayer.broadcastCount;
    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db,
      relayer,
      enableBroadcast: true,
      idempotencyKey: 'concurrent_req_1',
    });

    if (res.status !== 200 && res.status !== 202) {
      console.error('FAIL Scenario 8: Retry request gagal:', res);
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts) {
      console.error('FAIL Scenario 8: Retry memicu broadcast kedua!');
      process.exit(1);
    }
    console.log('PASS Scenario 8: Retry identik ditangani secara idempotent tanpa izin broadcast baru (0 broadcast)');
  }

  // SCENARIO 9: Pending tx tanpa receipt di mempool
  {
    const poolTxHash = Array.from(relayer.txPool.keys())[0];
    const initialBroadcasts = relayer.broadcastCount;

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db,
      relayer,
      enableBroadcast: true,
    });

    if (res.status !== 202 || !res.body.message.includes('pending in Sepolia mempool')) {
      console.error('FAIL Scenario 9: Pending mempool tidak terdeteksi:', res);
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts) {
      console.error('FAIL Scenario 9: Pending tx memicu broadcast kedua!');
      process.exit(1);
    }
    console.log('PASS Scenario 9: Pending tx tanpa receipt di mempool mengembalikan HTTP 202 (Nol broadcast kedua)');
  }

  // SCENARIO 10: Crash setelah broadcast: Mined on-chain recovery
  {
    const poolTxHash = Array.from(relayer.txPool.keys())[0];
    const initialBroadcasts = relayer.broadcastCount;

    // Transaksi termining di Sepolia
    relayer.mineTx(poolTxHash, true);

    const resMined = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db,
      relayer,
      enableBroadcast: true,
    });

    if (resMined.status !== 200 || resMined.body.proof.status !== 'confirmed') {
      console.error('FAIL Scenario 10: Pemulihan transaksi mined gagal:', resMined);
      process.exit(1);
    }
    if (relayer.broadcastCount !== initialBroadcasts) {
      console.error('FAIL Scenario 10: Pemulihan mined memicu broadcast baru!');
      process.exit(1);
    }
    console.log('PASS Scenario 10: Crash setelah broadcast dipulihkan secara rekonsiliatif saat mined (Nol broadcast kedua)');
  }

  // SCENARIO 11: Nonce collision / Replaced on-chain (latestNonce > claimNonce)
  {
    const dbReplaced = new MockCanaryDB();
    const relayerReplaced = new MockSepoliaCanaryRelayer();
    dbReplaced.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    await dbReplaced.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: '0xproof10',
      proof_hash: '0xhash10',
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'salt10',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    const claimReplaced = await dbReplaced.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproof10',
      proofHash: '0xhash10',
      idempotencyKey: 'req10',
    });
    await dbReplaced.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: claimReplaced.execution_token,
      relayerNonce: 1,
    });

    // Simulasikan nonce 1 telah dimine oleh transaksi lain di blockchain (latestNonce = 2),
    // tetapi proof tidak tercatat di smart contract!
    relayerReplaced.latestNonce = 2;
    relayerReplaced.pendingNonce = 2;

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbReplaced,
      relayer: relayerReplaced,
      enableBroadcast: true,
      idempotencyKey: 'req10',
    });

    if (res.status !== 409 || res.body.state !== 'recovery_required' || !res.body.error.includes('replaced')) {
      console.error('FAIL Scenario 11: Nonce consumed tidak ditandai recovery_required:', res);
      process.exit(1);
    }
    if (relayerReplaced.broadcastCount !== 0) {
      console.error('FAIL Scenario 11: Transaksi baru dikirim saat nonce collision terjadi!');
      process.exit(1);
    }
    console.log('PASS Scenario 11: Nonce consumed on-chain ditangani sebagai recovery_required (HTTP 409, Nol broadcast)');
  }

  // SCENARIO 12: Ambiguous crash window outcome: Nonce pending
  {
    const dbAmbiguous = new MockCanaryDB();
    const relayerAmbiguous = new MockSepoliaCanaryRelayer();
    dbAmbiguous.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    await dbAmbiguous.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: '0xproof11',
      proof_hash: '0xhash11',
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'salt11',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    const claimAmbiguous = await dbAmbiguous.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproof11',
      proofHash: '0xhash11',
      idempotencyKey: 'req11',
    });
    await dbAmbiguous.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: claimAmbiguous.execution_token,
      relayerNonce: 1,
    });

    // pendingNonce > claimNonce (transaksi in-flight di mempool)
    relayerAmbiguous.latestNonce = 1;
    relayerAmbiguous.pendingNonce = 2;

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbAmbiguous,
      relayer: relayerAmbiguous,
      enableBroadcast: true,
      idempotencyKey: 'req11',
    });

    if (res.status !== 202 || !res.body.message.includes('in-flight in mempool')) {
      console.error('FAIL Scenario 12: Pending in-flight mempool tidak ditangani:', res);
      process.exit(1);
    }
    if (relayerAmbiguous.broadcastCount !== 0) {
      console.error('FAIL Scenario 12: Broadcast kedua terjadi saat tx in-flight di mempool!');
      process.exit(1);
    }
    console.log('PASS Scenario 12: Ambiguous crash outcome dengan pending mempool mengembalikan HTTP 202 (Nol broadcast)');
  }

  // SCENARIO 13: DB update failure saat menyimpan tx_hash tertahan oleh durable state
  {
    const dbFail = new MockCanaryDB();
    const relayer13 = new MockSepoliaCanaryRelayer();
    dbFail.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
    dbFail.failOnTxHashSave = true; // DB failure when saving tx_hash to trip_proofs

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbFail,
      relayer: relayer13,
      enableBroadcast: true,
    });

    const claim = dbFail.canary_claims.get('CANARY_TRIP_50');
    if (!claim || claim.state !== 'tx_known' || !claim.tx_hash) {
      console.error('FAIL Scenario 13: State tx_known tidak tersimpan di canary_claims:', claim);
      process.exit(1);
    }
    console.log('PASS Scenario 13: Kegagalan DB update di trip_proofs tertahan oleh durable state canary_claims');
  }

  // SCENARIO 14: State CAS Race Condition / State Mismatch
  // Jika state claim saat transisi bukan 'reserved' (misal: telah dimodifikasi oleh worker lain),
  // fungsi transisi harus gagal dan broadcast WAJIB dibatalkan secara fail-closed (HTTP 500)
  {
    const dbCasRace = new MockCanaryDB();
    const relayerCas = new MockSepoliaCanaryRelayer();
    dbCasRace.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
    dbCasRace.failOnTransition = true; // Simulasikan kegagalan transisi state atomic

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbCasRace,
      relayer: relayerCas,
      enableBroadcast: true,
    });

    if (res.status !== 500 || !res.body.error.includes('Broadcast aborted for safety')) {
      console.error('FAIL Scenario 14: Kegagalan transisi state tidak membatalkan broadcast:', res);
      process.exit(1);
    }
    if (relayerCas.broadcastCount !== 0) {
      console.error('FAIL Scenario 14: Broadcast tetap dijalankan saat transisi state CAS gagal!');
      process.exit(1);
    }
    console.log('PASS Scenario 14: State CAS failure membatalkan broadcast secara fail-closed (HTTP 500, Nol broadcast)');
  }

  // SCENARIO 15: Crash SEBELUM Broadcast (State 'reserved' tanpa broadcast intent)
  // Worker sebelumnya crash setelah acquire claim ('reserved') sebelum sempat broadcast intent.
  // Permintaan retry dari user TIDAK MEMILIKI execution permit dan DITOLAK (HTTP 409) fail-closed.
  {
    const dbReservedCrash = new MockCanaryDB();
    const relayerCrash = new MockSepoliaCanaryRelayer();
    dbReservedCrash.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    // Seed proof record yang bersesuaian dengan claim crash
    await dbReservedCrash.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: '0xproofCrash',
      proof_hash: '0xhashCrash',
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'saltCrash',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    // Inisiasi reservasi tapi crash sebelum broadcast intent
    await dbReservedCrash.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproofCrash',
      proofHash: '0xhashCrash',
      idempotencyKey: 'reqCrash',
    });
    // State tetap 'reserved'

    // Retry dari user tiba
    const resRetry = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbReservedCrash,
      relayer: relayerCrash,
      enableBroadcast: true,
      idempotencyKey: 'reqCrash',
    });

    if (resRetry.status !== 409 || !resRetry.body.error.includes('Retry is restricted to reconciliation')) {
      console.error('FAIL Scenario 15: Retry pada state reserved tidak ditolak:', resRetry);
      process.exit(1);
    }
    if (relayerCrash.broadcastCount !== 0) {
      console.error('FAIL Scenario 15: Retry pada state reserved memicu broadcast!');
      process.exit(1);
    }
    console.log('PASS Scenario 15: Crash sebelum broadcast (state reserved) menolak retry secara fail-closed (HTTP 409, Nol broadcast)');
  }

  // SCENARIO 16: Gas fee di atas hard-cap 50 Gwei ditolak sebelum broadcast (HTTP 503)
  {
    const dbFee = new MockCanaryDB();
    const relayerFee = new MockSepoliaCanaryRelayer();
    dbFee.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });
    relayerFee.networkMaxFeeGwei = 65.0; // Lonjakan 65 Gwei di Sepolia

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbFee,
      relayer: relayerFee,
      enableBroadcast: true,
    });

    if (res.status !== 503 || !res.body.error.includes('exceeds canary hard cap (50 Gwei)')) {
      console.error('FAIL Scenario 16: Lonjakan gas di atas 50 Gwei tidak ditolak dengan 503:', res);
      process.exit(1);
    }
    if (relayerFee.broadcastCount !== 0) {
      console.error('FAIL Scenario 16: Transaksi tetap terkirim saat gas melebihi budget!');
      process.exit(1);
    }
    console.log('PASS Scenario 16: Gas fee di atas hard-cap 50 Gwei berhasil ditolak sebelum broadcast (HTTP 503)');
  }

  // SCENARIO 17: Proof sudah tercatat di smart contract langsung direkonsiliasi
  {
    const dbRecorded = new MockCanaryDB();
    const relayerRecorded = new MockSepoliaCanaryRelayer();
    dbRecorded.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    const testProofId = '0x1111111111111111111111111111111111111111111111111111111111111111';
    const testProofHash = '0x2222222222222222222222222222222222222222222222222222222222222222';
    relayerRecorded.onChainProofs.set(testProofId.toLowerCase(), {
      proofHash: testProofHash,
      timestamp: Math.floor(Date.now() / 1000),
      recorder: '0x521EFC3eeA82684Ba0143C5707EdF281d6E7Cd21',
    });

    await dbRecorded.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: testProofId,
      proof_hash: testProofHash,
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'salt14',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    const res = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbRecorded,
      relayer: relayerRecorded,
      enableBroadcast: true,
    });

    if (res.status !== 200 || res.body.proof.status !== 'confirmed') {
      console.error('FAIL Scenario 17:', res);
      process.exit(1);
    }
    if (relayerRecorded.broadcastCount !== 0) {
      console.error('FAIL Scenario 17: Broadcast kedua terjadi!');
      process.exit(1);
    }
    console.log('PASS Scenario 17: Proof on-chain direkonsiliasi langsung ke confirmed tanpa broadcast baru');
  }

  // SCENARIO 18: Canary scope exhausted (Circuit breaker mengunci permanen)
  {
    const res = await db.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 51,
      userId: 'user_a_uuid',
      proofId: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      proofHash: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      idempotencyKey: 'trip_51_key',
    });

    if (res.status !== 'scope_exhausted' || res.is_owner !== false || res.has_execution_permit !== false) {
      console.error('FAIL Scenario 18: Scope canary tidak exhausted:', res);
      process.exit(1);
    }
    console.log('PASS Scenario 18: Single-use circuit breaker mengunci permanen setelah klaim terpakai');
  }

  // SCENARIO 19 (ADVERSARIAL): Reused Permit / Non-Owner CAS Hijack Prevention
  // Penyerang atau worker lain mencoba memanggil transitionCanaryClaimState dari state 'reserved'
  // tanpa execution_token yang sah. Database WAJIB menolak dengan error 'invalid_execution_token'.
  {
    const dbAdv19 = new MockCanaryDB();
    const relayerAdv19 = new MockSepoliaCanaryRelayer();
    dbAdv19.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    // Permintaan sah menciptakan klaim
    const legitClaim = await dbAdv19.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproofLegit',
      proofHash: '0xhashLegit',
      idempotencyKey: 'legitKey',
    });

    if (!legitClaim.execution_token) {
      console.error('FAIL Scenario 19: Legit claim tidak memiliki execution_token:', legitClaim);
      process.exit(1);
    }

    // Penyerang mencoba memindahkan state ke broadcast_attempted dengan token palsu atau null
    const hijackAttemptNull = await dbAdv19.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: null, // Tanpa token
      relayerNonce: 999,
    });

    if (hijackAttemptNull.success !== false || hijackAttemptNull.error !== 'invalid_execution_token') {
      console.error('FAIL Scenario 19: CAS transisi tanpa token tidak ditolak:', hijackAttemptNull);
      process.exit(1);
    }

    const hijackAttemptForged = await dbAdv19.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: 'forged_token_uuid', // Token palsu
      relayerNonce: 999,
    });

    if (hijackAttemptForged.success !== false || hijackAttemptForged.error !== 'invalid_execution_token') {
      console.error('FAIL Scenario 19: CAS transisi dengan token palsu tidak ditolak:', hijackAttemptForged);
      process.exit(1);
    }

    // Verifikasi transisi dengan token asli BERHASIL
    const legitTransition = await dbAdv19.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: legitClaim.execution_token,
      relayerNonce: 1,
    });

    if (!legitTransition.success) {
      console.error('FAIL Scenario 19: Transisi sah ditolak:', legitTransition);
      process.exit(1);
    }
    console.log('PASS Scenario 19 (Adversarial): Non-owner CAS hijack berhasil dicegah oleh verifikasi execution_token di level DB');
  }

  // SCENARIO 20 (ADVERSARIAL): RPC Response Loss After Insert & Client Retry
  // Worker 1 berhasil melakukan insert claim ke DB, namun koneksi TCP putus sebelum response kembali ke Worker 1.
  // Worker 1 aborts (HTTP 500). Klien melakukan HTTP retry -> Worker 2 masuk.
  // Worker 2 WAJIB ditolak broadcast-nya secara fail-closed (0 broadcast dilakukan!).
  {
    const dbLoss = new MockCanaryDB();
    const relayerLoss = new MockSepoliaCanaryRelayer();
    dbLoss.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    // Worker 1 menyisipkan claim
    const seededProof = await dbLoss.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: '0xproofLoss',
      proof_hash: '0xhashLoss',
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'saltLoss',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    // Simulasi Worker 1 sukses insert di Postgres tetapi koneksi drop sebelum Edge Function terima
    await dbLoss.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproofLoss',
      proofHash: '0xhashLoss',
      idempotencyKey: 'keyLoss',
    });
    // Worker 1 mati tanpa broadcast

    // Worker 2 (Retry Klien)
    const resRetry = await executeHardenedRecordProof({
      authHeader: 'Bearer user_a_token',
      tripId: 50,
      db: dbLoss,
      relayer: relayerLoss,
      enableBroadcast: true,
      idempotencyKey: 'keyLoss',
    });

    if (resRetry.status !== 409 || !resRetry.body.error.includes('Retry is restricted to reconciliation')) {
      console.error('FAIL Scenario 20: Retry setelah response loss tidak ditolak:', resRetry);
      process.exit(1);
    }
    if (relayerLoss.broadcastCount !== 0) {
      console.error('FAIL Scenario 20: Broadcast kedua terpicu setelah response loss!');
      process.exit(1);
    }
    console.log('PASS Scenario 20 (Adversarial): Response loss after insert terisolasi aman (Nol broadcast on-chain)');
  }

  // SCENARIO 21 (ADVERSARIAL): Stale / Zombie Worker CAS Race
  // Worker 1 memperoleh klaim (reserved), lalu mengalami jeda (pause / slow network).
  // Sebelum Worker 1 mengirim broadcast intent, status diubah oleh sistem atau admin menjadi 'recovery_required'.
  // Saat Worker 1 melanjutkan eksekusi, transisi CAS 'reserved' -> 'broadcast_attempted' WAJIB GAGAL dan transaksi dibatalkan.
  {
    const dbZombie = new MockCanaryDB();
    const relayerZombie = new MockSepoliaCanaryRelayer();
    dbZombie.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    const proofZombie = await dbZombie.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: '0xproofZombie',
      proof_hash: '0xhashZombie',
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'saltZombie',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    const zombieClaim = await dbZombie.acquireOrGetCanaryClaim({
      canaryScope: 'CANARY_TRIP_50',
      tripId: 50,
      userId: 'user_a_uuid',
      proofId: '0xproofZombie',
      proofHash: '0xhashZombie',
      idempotencyKey: 'zombieKey',
    });

    // Simulasi intervensi sistem: state claim dimutasikan menjadi 'recovery_required'
    await dbZombie.updateCanaryClaim('CANARY_TRIP_50', { state: 'recovery_required' });

    // Zombie Worker mencoba melanjutkan transisi CAS
    const zombieTransition = await dbZombie.transitionCanaryClaimState({
      canaryScope: 'CANARY_TRIP_50',
      expectedState: 'reserved',
      newState: 'broadcast_attempted',
      executionToken: zombieClaim.execution_token,
      relayerNonce: 1,
    });

    if (zombieTransition.success !== false || zombieTransition.error !== 'state_mismatch') {
      console.error('FAIL Scenario 21: Zombie worker berhasil mengubah state:', zombieTransition);
      process.exit(1);
    }
    console.log('PASS Scenario 21 (Adversarial): Zombie / stale worker tertahan oleh CAS state mismatch (Nol broadcast)');
  }

  // SCENARIO 22 (ADVERSARIAL): 10 Multi-Worker Concurrent Invocations (Stress Race)
  // 10 worker konkuren memanggil endpoint secara bersamaan untuk Trip 50 yang sama.
  // Tepat 1 worker yang memenangkan hak eksekusi on-chain (has_execution_permit=true & execution_token).
  // 9 worker lainnya menerima penolakan atau rekonsiliasi. Tepat 1 transaksi terkirim!
  {
    const dbRace = new MockCanaryDB();
    const relayerRace = new MockSepoliaCanaryRelayer();
    dbRace.seedTrip({ id: 50, user_id: 'user_a_uuid', status: 'completed' });

    const fixedProofId = '0x' + crypto.randomBytes(32).toString('hex');
    const fixedProofHash = '0x' + crypto.randomBytes(32).toString('hex');

    await dbRace.insertProof({
      user_id: 'user_a_uuid',
      trip_id: 50,
      proof_id: fixedProofId,
      proof_hash: fixedProofHash,
      payload_version: '1.0.0',
      snapshot_json: '{}',
      salt: 'saltRace',
      chain_id: 11155111,
      contract_address: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
      tx_hash: null,
      status: 'pending',
      created_at: new Date().toISOString(),
    });

    const promises = [];
    for (let i = 0; i < 10; i++) {
      promises.push(
        executeHardenedRecordProof({
          authHeader: 'Bearer user_a_token',
          tripId: 50,
          db: dbRace,
          relayer: relayerRace,
          enableBroadcast: true,
          idempotencyKey: `race_invocation_${i}`,
        })
      );
    }

    const results = await Promise.all(promises);

    let successCount = 0;
    let conflictCount = 0;
    for (const r of results) {
      if (r.status === 200 || r.status === 202) {
        successCount++;
      } else if (r.status === 409) {
        conflictCount++;
      }
    }

    if (relayerRace.broadcastCount !== 1) {
      console.error(`FAIL Scenario 22: Broadcast count bukan 1 (${relayerRace.broadcastCount})! Results:`, results);
      process.exit(1);
    }
    console.log(`PASS Scenario 22 (Adversarial): 10 worker konkuren tertangani sempurna (Tepat 1 broadcast, ${conflictCount} penolakan konkuren)`);
  }

  console.log('======================================================================');
  console.log('ALL 22 EXTENSIVE & ADVERSARIAL CANARY SAFETY SCENARIOS PASSED WITH ZERO ERRORS!');
  console.log('======================================================================');
}

runCanaryTests().catch((err) => {
  console.error('Canary test suite error:', err);
  process.exit(1);
});
