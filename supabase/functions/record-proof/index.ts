// Supabase Edge Function: record-proof
// Endpoint backend tepercaya untuk validasi dan relayer Proof of Visit ke Ethereum Sepolia.
//
// KEAMANAN & PRINSIP UTAMA:
// 1. Private key relayer TIDAK PERNAH dikirim ke client Flutter.
// 2. Memvalidasi token JWT Supabase user secara server-side.
// 3. Memastikan trip benar-benar berstatus 'completed' dan milik user yang memanggil.
// 4. Menghasilkan hash kanonis SHA-256 bebas PII di backend.
// 5. ATOMIC IDEMPOTENCY: Menjamin 1 trip hanya menghasilkan 1 proof melalui locking & UNIQUE (trip_id) di PostgreSQL.
// 6. SAFE BY DEFAULT: Mode broadcast on-chain dinonaktifkan secara default (DRY-RUN).
//    Hanya melakukan broadcast jika ENABLE_ONCHAIN_BROADCAST === "true" dan RELAYER_PRIVATE_KEY tersedia.
// 7. RESILIENT RECOVERY: Pemulihan transaksi on-chain otomatis bahkan jika pencatatan tx_hash ke DB sempat gagal.
//    Mencegah broadcast ganda atau pembuatan proofId baru pada retry.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ethers } from "npm:ethers@6.13.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ABI minimal smart contract MeraTripProof
const CONTRACT_ABI = [
  "function recordProof(bytes32 proofId, bytes32 proofHash) external",
  "function getProof(bytes32 proofId) external view returns (bytes32 proofHash, uint256 timestamp, address recorder)",
  "function verifyProof(bytes32 proofId, bytes32 proofHash) external view returns (bool isValid)",
  "function isProofRecorded(bytes32 proofId) external view returns (bool)",
  "function totalProofsCount() external view returns (uint256)",
  "event ProofRecorded(bytes32 indexed proofId, bytes32 indexed proofHash, address indexed recorder, uint256 timestamp)",
];

// Daftar endpoint RPC Sepolia publik terverifikasi sehat untuk fallback
const SEPOLIA_RPC_FALLBACKS = [
  "https://ethereum-sepolia-rpc.publicnode.com",
  "https://1rpc.io/sepolia",
  "https://sepolia.drpc.org",
  "https://gateway.tenderly.co/public/sepolia",
];

function createResilientSepoliaProvider(primaryUrl: string, expectedChainId: number): ethers.FallbackProvider | ethers.JsonRpcProvider {
  const cleanPrimary = (primaryUrl || "").replace(/["']/g, "").trim();
  const endpoints = [
    cleanPrimary,
    ...SEPOLIA_RPC_FALLBACKS,
  ].filter((url, idx, arr) => Boolean(url) && arr.indexOf(url) === idx);

  if (endpoints.length <= 1) {
    const fetchReq = new ethers.FetchRequest(endpoints[0] || SEPOLIA_RPC_FALLBACKS[0]);
    fetchReq.timeout = 7000;
    return new ethers.JsonRpcProvider(fetchReq, expectedChainId, { staticNetwork: true });
  }

  const configs = endpoints.map((url, index) => {
    const fetchReq = new ethers.FetchRequest(url);
    fetchReq.timeout = 5000; // 5s timeout per node
    const provider = new ethers.JsonRpcProvider(fetchReq, expectedChainId, { staticNetwork: true });
    return {
      provider,
      priority: index + 1,
      weight: 1,
      stallTimeout: 2500,
    };
  });

  return new ethers.FallbackProvider(configs, expectedChainId, { quorum: 1 });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").trim();
    const supabaseAnonKey = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
    const supabaseServiceKey = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
    const sepoliaRpcUrl = (Deno.env.get("SEPOLIA_RPC_URL") ?? "https://ethereum-sepolia-rpc.publicnode.com").trim();
    const rawContractAddress = (Deno.env.get("CONTRACT_ADDRESS") ?? "0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D").trim();
    const relayerPrivateKey = (Deno.env.get("RELAYER_PRIVATE_KEY") ?? "").trim();
    const enableBroadcast = (Deno.env.get("ENABLE_ONCHAIN_BROADCAST") ?? "").trim() === "true";
    const expectedChainId = 11155111;

    if (!ethers.isAddress(rawContractAddress)) {
      console.error(`[record-proof] Fatal configuration error: CONTRACT_ADDRESS is not a valid Ethereum address: "${rawContractAddress}"`);
      return new Response(JSON.stringify({ error: "Server configuration error: Invalid contract address format" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const contractAddress = ethers.getAddress(rawContractAddress);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Validasi Autentikasi User via Supabase Client
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized user session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { trip_id, trip_name } = body;
    let numericTripId = Number(trip_id);

    if (
      trip_id === undefined ||
      trip_id === null ||
      trip_id === "" ||
      !Number.isSafeInteger(numericTripId) ||
      numericTripId <= 0
    ) {
      return new Response(
        JSON.stringify({ error: "trip_id is required or invalid" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ON-CHAIN BROADCAST SAFETY CONSTANTS & DYNAMIC PER-TRIP ATOMIC SCOPE
    const CANARY_SCOPE = `TRIP_${numericTripId}`;
    const HARD_CAP_MAX_FEE = ethers.parseUnits("50", "gwei"); // 50 Gwei hard cap
    const HARD_CAP_PRIORITY_FEE = ethers.parseUnits("5", "gwei"); // 5 Gwei priority cap
    const MAX_ALLOWED_BUDGET_ETH = ethers.parseEther("0.025"); // 0.025 SepoliaETH budget limit
    const MAX_GAS_LIMIT = 750000n; // 750k units upper bound (safe buffer for SSTORE + events)

    const reqId = crypto.randomUUID().slice(0, 8);
    const hasServiceRoleKey = Boolean(supabaseServiceKey && supabaseServiceKey.trim().length > 0);
    const adminClient = createClient(supabaseUrl, supabaseServiceKey || supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 2. Validasi Kepemilikan & Status Trip
    console.log(
      `[record-proof][${reqId}] Fetching trip: id=${numericTripId}, hasServiceKey=${hasServiceRoleKey}`,
    );

    let { data: trip, error: tripError } = await adminClient
      .from("trips")
      .select("*")
      .eq("id", numericTripId)
      .maybeSingle();

    if (!trip && supabaseClient) {
      const { data: userTrip } = await supabaseClient
        .from("trips")
        .select("*")
        .eq("id", numericTripId)
        .maybeSingle();
      if (userTrip) {
        trip = userTrip;
        tripError = null;
      }
    }

    if (!trip && trip_name && typeof trip_name === "string" && trip_name.trim().length > 0) {
      console.log(
        `[record-proof][${reqId}] Fallback: searching trip by user_id and trip_name="${trip_name.trim()}"`,
      );
      const { data: tripByName } = await adminClient
        .from("trips")
        .select("*")
        .eq("user_id", user.id)
        .ilike("trip_name", trip_name.trim())
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (tripByName) {
        trip = tripByName;
        numericTripId = Number(tripByName.id);
        tripError = null;
        console.log(
          `[record-proof][${reqId}] Trip matched by name, resolved to cloud trip_id=${numericTripId}`,
        );
      }
    }

    const tripFound = Boolean(trip);

    if (tripError || !trip) {
      console.warn(
        `[record-proof][${reqId}] Trip fetch failed: found=${tripFound}, code=${tripError?.code ?? "NONE"}, message=${tripError?.message ?? "Not found"}, details=${tripError?.details ?? "none"}`,
      );
      return new Response(JSON.stringify({ error: "Trip not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(
      `[record-proof][${reqId}] Trip fetch success: found=true, id=${numericTripId}, status=${trip.status}`,
    );

    if (trip.user_id !== user.id && trip.user_id?.toString() !== user.id) {
      return new Response(JSON.stringify({ error: "Trip does not belong to the authenticated user" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (trip.status !== "completed") {
      return new Response(JSON.stringify({ error: "Trip must be completed to generate proof of visit" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Provider Read-Only ke Ethereum Sepolia
    const provider = createResilientSepoliaProvider(sepoliaRpcUrl, expectedChainId);
    const readOnlyContract = new ethers.Contract(contractAddress, CONTRACT_ABI, provider);

    // 4. ATOMIC CHECK & NON-ATOMIC RECOVERY
    const { data: existingProof } = await adminClient
      .from("trip_proofs")
      .select("*")
      .eq("trip_id", numericTripId)
      .maybeSingle();

    let activeProof = existingProof;

    if (existingProof) {
      // 4A. Sudah confirmed
      if (existingProof.status === "confirmed") {
        return new Response(JSON.stringify({
          message: "Existing proof confirmed on-chain",
          proof: existingProof,
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 4A-2. Sudah simulated dalam mode dry-run
      if (existingProof.status === "simulated") {
        if (!enableBroadcast || !relayerPrivateKey) {
          return new Response(JSON.stringify({
            message: "Existing dry-run proof simulation verified",
            proof: existingProof,
            mode: "dry_run",
            broadcast_enabled: false,
            simulation_passed: true,
          }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }

      // 4B. Pending dengan tx_hash yang sudah tercatat
      if (existingProof.tx_hash && existingProof.status === "pending") {
        try {
          const receipt = await provider.getTransactionReceipt(existingProof.tx_hash);
          if (receipt && receipt.status === 1) {
            const confirmedAt = new Date().toISOString();
            const { data: confirmedRecord } = await adminClient
              .from("trip_proofs")
              .update({ status: "confirmed", confirmed_at: confirmedAt })
              .eq("id", existingProof.id)
              .select()
              .single();

            return new Response(JSON.stringify({
              message: "Pending transaction recovered and confirmed on-chain",
              proof: confirmedRecord || { ...existingProof, status: "confirmed", confirmed_at: confirmedAt },
            }), {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          } else if (receipt && receipt.status === 0) {
            const { data: failedRecord } = await adminClient
              .from("trip_proofs")
              .update({ status: "failed" })
              .eq("id", existingProof.id)
              .select()
              .single();

            return new Response(JSON.stringify({
              error: "Previous on-chain transaction reverted during execution",
              proof: failedRecord || { ...existingProof, status: "failed" },
            }), {
              status: 400,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          } else {
            // Masih di mempool
            return new Response(JSON.stringify({
              message: "Transaction is currently pending in Sepolia mempool",
              proof: existingProof,
            }), {
              status: 202,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }
        } catch (_) {
          return new Response(JSON.stringify({
            message: "Previous transaction is pending, RPC verification in progress",
            proof: existingProof,
          }), {
            status: 202,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }

      // 4C. Pending tanpa tx_hash (Kemungkinan: broadcast on-chain berhasil tetapi simpan tx_hash gagal)
      try {
        const isRecorded = await readOnlyContract.isProofRecorded(existingProof.proof_id);
        if (isRecorded) {
          const onChain = await readOnlyContract.getProof(existingProof.proof_id);
          // Verifikasi integritas hash
          if (onChain.proofHash.toLowerCase() !== existingProof.proof_hash.toLowerCase()) {
            return new Response(JSON.stringify({
              error: "Proof ID conflict detected on-chain with a conflicting hash",
            }), {
              status: 409,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }

          // Sukses pulih: transaksi sebenarnya sudah tercatat di blockchain!
          const confirmedAt = new Date(Number(onChain.timestamp) * 1000).toISOString();
          const { data: recoveredRecord } = await adminClient
            .from("trip_proofs")
            .update({ status: "confirmed", confirmed_at: confirmedAt })
            .eq("id", existingProof.id)
            .select()
            .single();

          return new Response(JSON.stringify({
            message: "Proof recovered successfully from Ethereum Sepolia",
            proof: recoveredRecord || { ...existingProof, status: "confirmed", confirmed_at: confirmedAt },
          }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      } catch (_) {
        // Abaikan error read-only RPC sementara
      }

      // Jika belum recorded on-chain dan dibuat kurang dari 25 detik yang lalu:
      // Instance lain kemungkinan sedang dalam proses broadcast!
      const createdAtMs = new Date(existingProof.created_at).getTime();
      const nowMs = Date.now();
      if (enableBroadcast && nowMs - createdAtMs < 25000 && existingProof.status === "pending") {
        return new Response(JSON.stringify({
          message: "Proof generation currently in progress, please wait",
          proof: existingProof,
        }), {
          status: 202,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // 5. JIKA BELUM ADA PROOF: BUAT RECORD BARU DENGAN ATOMIC LOCK DI DB
    let proofId: string;
    let proofHash: string;
    let canonicalJson: string;
    let salt: string;

    if (activeProof) {
      // Gunakan kembali proof_id dan proof_hash yang sudah ada (Mencegah pembuatan proofId baru saat retry)
      proofId = activeProof.proof_id;
      proofHash = activeProof.proof_hash;
      canonicalJson = activeProof.snapshot_json;
      salt = activeProof.salt;
    } else {
      // Bangun payload kanonis baru
      const randomBytes = crypto.getRandomValues(new Uint8Array(32));
      salt = Array.from(randomBytes).map((b) => b.toString(16).padStart(2, "0")).join("");

      const proofIdBytes = crypto.getRandomValues(new Uint8Array(32));
      proofId = "0x" + Array.from(proofIdBytes).map((b) => b.toString(16).padStart(2, "0")).join("");

      const rawItems = Array.isArray(trip.items)
        ? trip.items
        : typeof trip.items === "string"
          ? JSON.parse(trip.items || "[]")
          : [];

      if (!Array.isArray(rawItems)) {
        throw new Error("Invalid trip itinerary format");
      }

      const destinations = rawItems
        .map((item: any) => ({
          destination_name: (
            item.item_name ||
            item.destination_name ||
            item.name ||
            ""
          ).toString().trim(),
          elevation_mdpl: Number(item.elevation_mdpl) || 0,
          is_visited:
            item.is_completed === 1 ||
            item.is_completed === true ||
            item.is_completed === "1",
        }))
        .sort((a, b) =>
          a.destination_name.localeCompare(b.destination_name)
        );

      if (destinations.length === 0) {
        return new Response(
          JSON.stringify({ error: "Trip itinerary has no destinations to generate proof" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      const encoder = new TextEncoder();
      const idDigest = await crypto.subtle.digest(
        "SHA-256",
        encoder.encode(`meratrip_trip_${numericTripId}_${salt}`)
      );
      const tripIdentifier = "0x" + Array.from(new Uint8Array(idDigest)).map((b) => b.toString(16).padStart(2, "0")).join("");

      const canonicalPayload = {
        completed_at: trip.completed_at || "",
        destinations: destinations,
        payload_version: "1.0.0",
        proof_id: proofId.toLowerCase(),
        salt: salt,
        start_date: (trip.start_date || "").trim(),
        total_destinations: destinations.length,
        trip_identifier: tripIdentifier,
      };

      const sortedKeys = Object.keys(canonicalPayload).sort();
      const sortedObj: Record<string, any> = {};
      for (const key of sortedKeys) {
        sortedObj[key] = (canonicalPayload as any)[key];
      }
      canonicalJson = JSON.stringify(sortedObj);

      const hashBuffer = await crypto.subtle.digest("SHA-256", encoder.encode(canonicalJson));
      proofHash = "0x" + Array.from(new Uint8Array(hashBuffer)).map((b) => b.toString(16).padStart(2, "0")).join("");

      const initialProofRecord = {
        user_id: user.id,
        trip_id: numericTripId,
        proof_id: proofId,
        proof_hash: proofHash,
        payload_version: "1.0.0",
        snapshot_json: canonicalJson,
        salt: salt,
        chain_id: expectedChainId,
        contract_address: contractAddress,
        tx_hash: null,
        status: "pending",
        created_at: new Date().toISOString(),
      };

      // ATOMIC INSERT: Dilindungi oleh UNIQUE (trip_id) di PostgreSQL
      const { data: insertedProof, error: insertError } = await adminClient
        .from("trip_proofs")
        .insert(initialProofRecord)
        .select()
        .single();

      if (insertError) {
        // Jika terjadi pelanggaran unique constraint karena request concurrent lain baru saja meng-insert:
        if (insertError.code === "23505" || insertError.message?.includes("unique")) {
          const { data: concurrentProof } = await adminClient
            .from("trip_proofs")
            .select("*")
            .eq("trip_id", numericTripId)
            .single();

          return new Response(JSON.stringify({
            message: "Concurrent request detected. Proof creation is already in progress.",
            proof: concurrentProof,
          }), {
            status: 202,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        throw insertError;
      }

      activeProof = insertedProof;
    }

    // 6. Validasi On-Chain State Sebelum Eksekusi (Anti-Tamper & Anti-Collision Check)
    try {
      const alreadyRecordedOnChain = await readOnlyContract.isProofRecorded(proofId);
      if (alreadyRecordedOnChain) {
        const onChain = await readOnlyContract.getProof(proofId);
        if (onChain.proofHash.toLowerCase() === proofHash.toLowerCase()) {
          // Sinkronkan ke database
          const confirmedAt = new Date(Number(onChain.timestamp) * 1000).toISOString();
          const { data: updatedRecord } = await adminClient
            .from("trip_proofs")
            .update({ status: "confirmed", confirmed_at: confirmedAt })
            .eq("id", activeProof.id)
            .select()
            .single();

          return new Response(JSON.stringify({
            message: "Proof already confirmed on Ethereum Sepolia",
            proof: updatedRecord || activeProof,
          }), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        } else {
          return new Response(JSON.stringify({
            error: "Proof ID conflict detected: Existing on-chain record has a conflicting hash.",
          }), {
            status: 409,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
    } catch (_) {
      // Abaikan jika RPC read gagal sementara
    }

    // 7. DRY-RUN VS ON-CHAIN BROADCAST
    // Secara default, fitur broadcast dinonaktifkan (DRY-RUN) demi keamanan
    if (!enableBroadcast || !relayerPrivateKey) {
      let simulationPassed = true;
      let simulationNote = "Dry-run mode aktif. Transaksi on-chain dinonaktifkan secara aman.";

      try {
        await readOnlyContract.recordProof.staticCall(proofId, proofHash);
        simulationNote += " Simulasi staticCall on-chain berhasil tanpa revert.";
      } catch (simErr: any) {
        simulationPassed = false;
        simulationNote += ` Simulasi staticCall gagal: ${simErr.message || simErr}`;
      }

      const dryRunStatus = simulationPassed ? "simulated" : "failed";
      const { data: updatedProof } = await adminClient
        .from("trip_proofs")
        .update({ status: dryRunStatus, contract_address: contractAddress })
        .eq("id", activeProof.id)
        .select()
        .single();

      return new Response(JSON.stringify({
        message: simulationNote,
        proof: updatedProof || { ...activeProof, status: dryRunStatus },
        mode: "dry_run",
        broadcast_enabled: false,
        simulation_passed: simulationPassed,
      }), {
        status: simulationPassed ? 201 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // 8. RELAYER ON-CHAIN BROADCAST (CANARY HARDENED - SINGLE USE CIRCUIT BREAKER)
    // =========================================================================
    try {
      const wallet = new ethers.Wallet(relayerPrivateKey, provider);
      const contractWithSigner = new ethers.Contract(contractAddress, CONTRACT_ABI, wallet);

      const network = await provider.getNetwork();
      if (Number(network.chainId) !== expectedChainId) {
        throw new Error(`Invalid RPC Network: Expected chain ID ${expectedChainId}, got ${network.chainId}`);
      }

      // 8A. ATOMIC CANARY CLAIM / SINGLE-USE CIRCUIT BREAKER (FAIL-SAFE)
      const idempotencyKey = req.headers.get("x-idempotency-key") || `canary_trip_${numericTripId}_proof_${proofId.slice(2, 10)}`;
      let canaryClaimRecord: any = null;
      let executionToken: string | null = null;

      try {
        // Reservasi atomik via RPC PostgreSQL
        const { data: rpcClaim, error: rpcErr } = await adminClient.rpc("acquire_or_get_canary_claim", {
          p_canary_scope: CANARY_SCOPE,
          p_trip_id: numericTripId,
          p_user_id: user.id,
          p_proof_id: proofId,
          p_proof_hash: proofHash,
          p_idempotency_key: idempotencyKey,
        });

        if (rpcErr) {
          console.error(`[record-proof][${reqId}] Canary circuit breaker: RPC execution error:`, rpcErr);
          return new Response(JSON.stringify({
            error: `Canary circuit breaker error: Failed to acquire atomic claim (${rpcErr.message || "Database RPC failure"}). Broadcast aborted for safety.`,
          }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        if (!rpcClaim) {
          console.error(`[record-proof][${reqId}] Canary circuit breaker: Empty response from claim reservation.`);
          return new Response(JSON.stringify({
            error: "Canary circuit breaker error: Empty response from reservation procedure. Broadcast aborted for safety.",
          }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        if (rpcClaim.status === "scope_exhausted" || !rpcClaim.is_owner) {
          console.warn(`[record-proof][${reqId}] Canary circuit breaker: Scope already exhausted by another claim`);
          return new Response(JSON.stringify({
            error: "Canary circuit breaker: Broadcast slot is already claimed and locked. Only one canary transaction is allowed.",
            canary_scope: CANARY_SCOPE,
            existing_claim: rpcClaim.claim,
          }), {
            status: 409,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        canaryClaimRecord = rpcClaim.claim;
        const hasExecutionPermit = rpcClaim.has_execution_permit === true;
        executionToken = rpcClaim.execution_token || null;

        // 8B. EXISTING CLAIM RECONCILIATION & IDEMPOTENT RESPONSE ONLY
        if (!hasExecutionPermit) {
          console.log(`[record-proof][${reqId}] Canary claim exists without execution permit (action: ${rpcClaim.action}). Routing to reconciliation/idempotent handler.`);

          // RECOVERY UNTUK PRE-BROADCAST FAILURE:
          // Jika klaim sebelumnya gagal SEBELUM broadcast (tx_hash dan relayer_nonce kosong),
          // izinkan retry aman dengan mereset state ke 'reserved' dan token baru.
          if (canaryClaimRecord.state === "failed_recoverable" && !canaryClaimRecord.tx_hash && !canaryClaimRecord.relayer_nonce) {
            console.log(`[record-proof][${reqId}] Recovering pre-broadcast failure for retry. Resetting claim state to reserved.`);
            const freshToken = crypto.randomUUID();
            const { error: resetErr } = await adminClient
              .from("canary_claims")
              .update({
                state: "reserved",
                execution_token: freshToken,
                error_message: null,
                updated_at: new Date().toISOString(),
              })
              .eq("canary_scope", CANARY_SCOPE);

            if (!resetErr) {
              canaryClaimRecord.state = "reserved";
              executionToken = freshToken;
              // Token diperbarui, bypass reconciliation handler dan lanjut langsung ke broadcast!
            } else {
              return new Response(JSON.stringify({
                error: `Failed to reset recoverable claim: ${resetErr.message}`,
              }), {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
              });
            }
          } else if (canaryClaimRecord.state === "confirmed") {
            // 1. Jika proof sudah confirmed on-chain
            return new Response(JSON.stringify({
              message: "Canary proof already confirmed on Ethereum Sepolia",
              proof: activeProof,
              canary_scope: CANARY_SCOPE,
              state: "confirmed",
            }), {
              status: 200,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          } else if (canaryClaimRecord.state === "tx_known" && canaryClaimRecord.tx_hash) {
            try {
              const receipt = await provider.getTransactionReceipt(canaryClaimRecord.tx_hash);
              if (receipt && receipt.status === 1) {
                const confirmedAt = new Date().toISOString();
                await adminClient.rpc("transition_canary_claim_state", {
                  p_canary_scope: CANARY_SCOPE,
                  p_expected_state: "tx_known",
                  p_new_state: "confirmed",
                  p_tx_hash: canaryClaimRecord.tx_hash,
                });

                const { data: confProof } = await adminClient.from("trip_proofs").update({
                  status: "confirmed",
                  tx_hash: canaryClaimRecord.tx_hash,
                  confirmed_at: confirmedAt,
                }).eq("id", activeProof.id).select().single();

                return new Response(JSON.stringify({
                  message: "Pending canary transaction recovered and confirmed on-chain",
                  proof: confProof || activeProof,
                  tx_hash: canaryClaimRecord.tx_hash,
                }), {
                  status: 200,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              } else if (receipt && receipt.status === 0) {
                return new Response(JSON.stringify({
                  error: "Previous canary transaction reverted on-chain during execution",
                  tx_hash: canaryClaimRecord.tx_hash,
                }), {
                  status: 400,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              }

              // Transaksi masih di mempool
              const mempoolTx = await provider.getTransaction(canaryClaimRecord.tx_hash);
              if (mempoolTx) {
                return new Response(JSON.stringify({
                  message: "Canary transaction is currently pending in Sepolia mempool",
                  tx_hash: canaryClaimRecord.tx_hash,
                  state: "tx_known",
                }), {
                  status: 202,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              }
            } catch (lookupErr) {
              console.warn(`[record-proof][${reqId}] Mempool lookup notice:`, lookupErr);
            }
          }

          // 3. Jika broadcast pernah dicoba (crash window), rekonsiliasi on-chain & relayer nonce
          if (canaryClaimRecord.state === "broadcast_attempted" || canaryClaimRecord.state === "recovery_required") {
            const isRecorded = await readOnlyContract.isProofRecorded(proofId);
            if (isRecorded) {
              const onChain = await readOnlyContract.getProof(proofId);
              if (onChain.proofHash.toLowerCase() === proofHash.toLowerCase()) {
                const confirmedAt = new Date(Number(onChain.timestamp) * 1000).toISOString();
                await adminClient.rpc("transition_canary_claim_state", {
                  p_canary_scope: CANARY_SCOPE,
                  p_expected_state: canaryClaimRecord.state,
                  p_new_state: "confirmed",
                  p_tx_hash: canaryClaimRecord.tx_hash || null,
                });

                const { data: recProof } = await adminClient.from("trip_proofs").update({
                  status: "confirmed",
                  confirmed_at: confirmedAt,
                }).eq("id", activeProof.id).select().single();

                return new Response(JSON.stringify({
                  message: "Canary proof recovered and verified on-chain",
                  proof: recProof || activeProof,
                }), {
                  status: 200,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              }
            }

            // Jika smart contract belum mencatat proof, JANGAN broadcast ulang secara otomatis!
            const claimNonce = canaryClaimRecord.relayer_nonce;
            if (claimNonce !== null && claimNonce !== undefined) {
              const latestNonce = await provider.getTransactionCount(wallet.address, "latest");
              const pendingNonce = await provider.getTransactionCount(wallet.address, "pending");

              // Nonce sudah dipakai di on-chain tetapi proof tidak tercatat
              if (latestNonce > claimNonce) {
                await adminClient.rpc("transition_canary_claim_state", {
                  p_canary_scope: CANARY_SCOPE,
                  p_expected_state: canaryClaimRecord.state,
                  p_new_state: "recovery_required",
                  p_error_message: `Nonce ${claimNonce} consumed on-chain without proof. Transaction was replaced or dropped.`,
                });

                return new Response(JSON.stringify({
                  error: `Canary nonce collision / replaced: Relayer nonce ${claimNonce} was consumed on-chain without recording proof. Manual administrative recovery required.`,
                  relayer_address: wallet.address,
                  relayer_nonce: claimNonce,
                  state: "recovery_required",
                }), {
                  status: 409,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              }

              // Transaksi masih antre di mempool
              if (pendingNonce > claimNonce) {
                return new Response(JSON.stringify({
                  message: `Canary broadcast is currently in-flight in mempool with nonce ${claimNonce}. Waiting for block inclusion.`,
                  relayer_address: wallet.address,
                  relayer_nonce: claimNonce,
                  state: "broadcast_attempted",
                }), {
                  status: 202,
                  headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
              }

              // Outcome ambigu: tandai recovery_required dan kembalikan HTTP 202
              await adminClient.rpc("transition_canary_claim_state", {
                p_canary_scope: CANARY_SCOPE,
                p_expected_state: canaryClaimRecord.state,
                p_new_state: "recovery_required",
                p_error_message: "Broadcast outcome ambiguous. Pending automatic reconciliation.",
              });

              return new Response(JSON.stringify({
                message: "Canary broadcast outcome is ambiguous. System has set state to recovery_required. No second transaction was created.",
                canary_scope: CANARY_SCOPE,
                state: "recovery_required",
                relayer_nonce: claimNonce,
              }), {
                status: 202,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
              });
            }
          }

          // 4. Jika state 'reserved': proses lain sedang berjalan atau crash sebelum broadcast intent dikunci.
          // JAMINAN SINGLE-USE: Retry DILARANG memulai broadcast baru.
          if (canaryClaimRecord.state === "reserved") {
            return new Response(JSON.stringify({
              error: "Canary claim is currently reserved by an in-flight execution. Retry is restricted to reconciliation and cannot broadcast.",
              canary_scope: CANARY_SCOPE,
              state: "reserved",
              action: "reconcile_only",
            }), {
              status: 409,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }

          // Fallback state rejection untuk existing claim lainnya (hanya jika bukan state reserved yang baru dipulihkan)
          if (canaryClaimRecord.state !== "reserved" || !executionToken) {
            return new Response(JSON.stringify({
              error: `Canary claim in state '${canaryClaimRecord.state}' cannot be re-executed. Broadcast aborted for safety.`,
              canary_scope: CANARY_SCOPE,
              state: canaryClaimRecord.state,
            }), {
              status: 409,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }
        }
      } catch (claimEx: any) {
        console.error(`[record-proof][${reqId}] Canary claim reservation exception:`, claimEx);
        return new Response(JSON.stringify({
          error: `Canary circuit breaker exception: ${claimEx.message || claimEx}. Broadcast aborted for safety.`,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // FAIL-SAFE: Hapus seluruh fallback yang memungkinkan broadcast tanpa claim valid
      if (!canaryClaimRecord) {
        return new Response(JSON.stringify({
          error: "Canary circuit breaker: No valid claim record found. Broadcast aborted for safety.",
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 8C. GAS BUDGET & HARD SAFETY CAP POLICY (HANYA DIEKSEKUSI OLEH PEMEGANG EXECUTION PERMIT)
      const feeData = await provider.getFeeData();

      // 1. Priority fee with hard cap (5 Gwei max)
      const rawPriorityFee = feeData.maxPriorityFeePerGas ?? ethers.parseUnits("2", "gwei");
      const maxPriorityFeePerGas = rawPriorityFee > HARD_CAP_PRIORITY_FEE ? HARD_CAP_PRIORITY_FEE : rawPriorityFee;

      // 2. Max fee per gas with hard cap (50 Gwei max - perbaikan bug nullish coalescing ??)
      const rawMaxFee = feeData.maxFeePerGas ?? ethers.parseUnits("25", "gwei");
      if (rawMaxFee > HARD_CAP_MAX_FEE) {
        console.error(`[record-proof][${reqId}] Network fee (${ethers.formatUnits(rawMaxFee, "gwei")} Gwei) exceeds hard cap (50 Gwei)`);
        return new Response(JSON.stringify({
          error: `Network fee surge: Current max fee (${ethers.formatUnits(rawMaxFee, "gwei")} Gwei) exceeds canary hard cap (50 Gwei). Transaction aborted.`,
        }), {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const maxFeePerGas = rawMaxFee;

      // 3. Gas limit policy: Explicit estimate + 20% safety buffer, bounded by MAX_GAS_LIMIT (500k)
      const estimatedGas = await contractWithSigner.recordProof.estimateGas(proofId, proofHash);
      const gasLimit = (estimatedGas * 120n) / 100n;
      if (gasLimit > MAX_GAS_LIMIT) {
        return new Response(JSON.stringify({
          error: `Gas limit policy violation: Estimated gas with buffer (${gasLimit.toString()}) exceeds upper limit (${MAX_GAS_LIMIT.toString()}).`,
        }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 4. Conservative Maximum Cost check against allowed budget (0.025 SepoliaETH)
      const conservativeMaxCost = gasLimit * maxFeePerGas;
      if (conservativeMaxCost > MAX_ALLOWED_BUDGET_ETH) {
        return new Response(JSON.stringify({
          error: `Budget limit violation: Conservative max cost (${ethers.formatEther(conservativeMaxCost)} SepoliaETH) exceeds canary budget (${ethers.formatEther(MAX_ALLOWED_BUDGET_ETH)} SepoliaETH).`,
        }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 8D. DETERMINISTIC NONCE & DURABLE TRANSACTION INTENT (FAIL-CLOSED STATE CAS)
      const relayerNonce = await provider.getTransactionCount(wallet.address, "pending");

      // Kunci transisi state ke 'broadcast_attempted' secara atomik di database SEBELUM memanggil RPC on-chain
      const { data: transitionRes, error: transitionErr } = await adminClient.rpc("transition_canary_claim_state", {
        p_canary_scope: CANARY_SCOPE,
        p_expected_state: "reserved",
        p_new_state: "broadcast_attempted",
        p_execution_token: executionToken,
        p_tx_hash: null,
        p_relayer_nonce: relayerNonce,
        p_gas_limit: Number(gasLimit),
        p_conservative_max_fee_gwei: Number(ethers.formatUnits(maxFeePerGas, "gwei")),
        p_error_message: null,
      });

      if (transitionErr || !transitionRes?.success) {
        console.error(`[record-proof][${reqId}] Canary state transition to broadcast_attempted failed:`, transitionErr || transitionRes);
        return new Response(JSON.stringify({
          error: `Canary circuit breaker error: Failed to lock atomic broadcast intent (${transitionErr?.message || transitionRes?.error || "State transition failed"}). Broadcast aborted for safety.`,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      await adminClient
        .from("trip_proofs")
        .update({ status: "pending" })
        .eq("id", activeProof.id);

      // 8E. ON-CHAIN BROADCAST WITH DETERMINISTIC OVERRIDES
      const tx = await contractWithSigner.recordProof(proofId, proofHash, {
        maxPriorityFeePerGas,
        maxFeePerGas,
        gasLimit,
        nonce: relayerNonce,
      });
      const txHash = tx.hash;
      console.log(`[CANARY_BROADCAST_SUCCESS][${reqId}] Canary Trip 50 broadcast submitted. TX_HASH: ${txHash}, NONCE: ${relayerNonce}`);

      // Perbarui state menjadi 'tx_known' secara atomik
      try {
        await adminClient.rpc("transition_canary_claim_state", {
          p_canary_scope: CANARY_SCOPE,
          p_expected_state: "broadcast_attempted",
          p_new_state: "tx_known",
          p_execution_token: executionToken,
          p_tx_hash: txHash,
          p_relayer_nonce: relayerNonce,
          p_gas_limit: null,
          p_conservative_max_fee_gwei: null,
          p_error_message: null,
        });
      } catch (txStateErr) {
        console.warn(`[record-proof][${reqId}] Non-fatal transition to tx_known error:`, txStateErr);
      }

      // RESILIENT TX HASH SAVING: Retry loop untuk mencatat tx_hash ke Supabase
      let savedTxHash = false;
      for (let attempt = 1; attempt <= 3; attempt++) {
        const { error: updateErr } = await adminClient
          .from("trip_proofs")
          .update({ tx_hash: txHash, status: "pending" })
          .eq("id", activeProof.id);

        if (!updateErr) {
          savedTxHash = true;
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 800));
      }

      if (!savedTxHash) {
        console.error("EMERGENCY: Gagal menyimpan tx_hash ke Supabase setelah 3 percobaan. TX Hash:", txHash);
      }

      // 8E. CONFIRMATION WAIT & FINAL RECONCILIATION
      let finalStatus = "pending";
      let confirmedAt: string | null = null;

      try {
        const receipt = await tx.wait(1);
        if (receipt && receipt.status === 1) {
          finalStatus = "confirmed";
          confirmedAt = new Date().toISOString();
          try {
            await adminClient.from("canary_claims").update({
              state: "confirmed",
              updated_at: confirmedAt,
            }).eq("canary_scope", CANARY_SCOPE);
          } catch (_) {}
        } else if (receipt && receipt.status === 0) {
          finalStatus = "failed";
          try {
            await adminClient.from("canary_claims").update({
              state: "failed_recoverable",
              error_message: "Transaction reverted on-chain during execution",
              updated_at: new Date().toISOString(),
            }).eq("canary_scope", CANARY_SCOPE);
          } catch (_) {}
        }
      } catch (receiptErr) {
        console.warn(`[CANARY_BROADCAST_TIMEOUT][${reqId}] Receipt wait timeout. Transaksi aman di mempool:`, txHash);
      }

      const { data: updatedProof } = await adminClient
        .from("trip_proofs")
        .update({
          tx_hash: txHash,
          status: finalStatus,
          confirmed_at: confirmedAt,
        })
        .eq("id", activeProof.id)
        .select()
        .single();

      return new Response(JSON.stringify({
        message: finalStatus === "confirmed"
          ? "Canary proof recorded and confirmed on Ethereum Sepolia"
          : "Canary proof transaction broadcast to Sepolia (pending confirmation in mempool)",
        proof: updatedProof || { ...activeProof, tx_hash: txHash, status: finalStatus },
        mode: "on_chain",
        broadcast_enabled: true,
        canary_scope: CANARY_SCOPE,
        tx_hash: txHash,
      }), {
        status: finalStatus === "confirmed" ? 200 : 202,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (broadcastErr: any) {
      const errMsg = broadcastErr.message || String(broadcastErr);
      console.error(`[CANARY_BROADCAST_ERROR][${reqId}] Broadcast execution failed:`, errMsg);

      // Bedakan definitive pre-broadcast failure dengan ambiguous broadcast outcome
      const isAmbiguous = errMsg.includes("timeout") ||
                          errMsg.includes("already known") ||
                          errMsg.includes("replacement") ||
                          errMsg.includes("nonce");

      if (!isAmbiguous) {
        // Definitive failure SEBELUM transaksi diterima jaringan
        try {
          await adminClient.from("canary_claims").update({
            state: "failed_recoverable",
            error_message: errMsg,
            updated_at: new Date().toISOString(),
          }).eq("canary_scope", CANARY_SCOPE);
        } catch (_) {}

        await adminClient
          .from("trip_proofs")
          .update({ status: "failed" })
          .eq("id", activeProof.id);

        return new Response(JSON.stringify({
          error: `Relayer definitive pre-broadcast error: ${errMsg}`,
          proof: { ...activeProof, status: "failed" },
        }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } else {
        // Ambiguous outcome: Transaksi mungkin sudah diterima node RPC / mempool
        // JANGAN tandai status failed di DB!
        return new Response(JSON.stringify({
          message: "Canary transaction broadcast status is ambiguous (pending in RPC or mempool). System has preserved state for automatic reconciliation.",
          proof: { ...activeProof, status: "pending" },
        }), {
          status: 202,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
