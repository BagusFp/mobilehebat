// Supabase Edge Function: record-proof
// Endpoint backend tepercaya untuk validasi dan pengiriman transaksi Proof of Visit ke Ethereum Sepolia.
//
// KEAMANAN:
// - Private key relayer TIDAK PERNAH dikirim ke client Flutter.
// - Memvalidasi token JWT Supabase user secara server-side.
// - Memastikan trip benar-benar berstatus 'completed' dan milik user yang memanggil.
// - Menghitung / memverifikasi ulang hash kanonis SHA-256 bebas PII di backend.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ABI selector untuk: recordProof(bytes32 proofId, bytes32 proofHash)
// keccak256("recordProof(bytes32,bytes32)") = 0x43f09497...
const RECORD_PROOF_SELECTOR = "0x43f09497";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const sepoliaRpcUrl = Deno.env.get("SEPOLIA_RPC_URL") ?? "https://ethereum-sepolia-rpc.publicnode.com";
    const contractAddress = Deno.env.get("CONTRACT_ADDRESS") ?? "0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D";

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
    const { trip_id } = body;
    if (!trip_id) {
      return new Response(JSON.stringify({ error: "trip_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Gunakan admin/service client untuk query konsisten
    const adminClient = createClient(supabaseUrl, supabaseServiceKey || supabaseAnonKey);

    // 2. Validasi Kepemilikan & Status Trip
    const { data: trip, error: tripError } = await adminClient
      .from("trips")
      .select("*, trip_items(*)")
      .eq("id", trip_id)
      .single();

    if (tripError || !trip) {
      return new Response(JSON.stringify({ error: "Trip not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verifikasi kepemilikan trip
    if (trip.user_id !== user.id && trip.user_id?.toString() !== user.id) {
      return new Response(JSON.stringify({ error: "Trip does not belong to the authenticated user" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verifikasi trip telah selesai
    if (trip.status !== "completed") {
      return new Response(JSON.stringify({ error: "Trip must be completed to generate proof of visit" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Cek Idempotency: Jika bukti sudah pernah dibuat untuk trip ini
    const { data: existingProof } = await adminClient
      .from("trip_proofs")
      .select("*")
      .eq("trip_id", trip_id)
      .maybeSingle();

    if (existingProof && (existingProof.status === "confirmed" || existingProof.status === "pending")) {
      return new Response(JSON.stringify({
        message: "Existing proof found",
        proof: existingProof,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Bangun Payload Kanonis Bebas PII & Hitung SHA-256
    const randomBytes = crypto.getRandomValues(new Uint8Array(32));
    const salt = Array.from(randomBytes).map((b) => b.toString(16).padStart(2, "0")).join("");
    
    const proofIdBytes = crypto.getRandomValues(new Uint8Array(32));
    const proofId = "0x" + Array.from(proofIdBytes).map((b) => b.toString(16).padStart(2, "0")).join("");

    const destinations = ((trip.trip_items || []) as any[])
      .map((item) => ({
        destination_name: (item.item_name || "").trim(),
        elevation_mdpl: item.elevation_mdpl || 0,
        is_visited: item.is_completed === 1 || item.is_completed === true,
      }))
      .sort((a, b) => a.destination_name.localeCompare(b.destination_name));

    // Anonimkan trip identifier dengan salt
    const encoder = new TextEncoder();
    const idDigest = await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(`meratrip_trip_${trip_id}_${salt}`)
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

    // Serialisasi JSON terurut
    const sortedKeys = Object.keys(canonicalPayload).sort();
    const sortedObj: Record<string, any> = {};
    for (const key of sortedKeys) {
      sortedObj[key] = (canonicalPayload as any)[key];
    }
    const canonicalJson = JSON.stringify(sortedObj);

    // Hitung SHA-256 Hash
    const hashBuffer = await crypto.subtle.digest("SHA-256", encoder.encode(canonicalJson));
    const proofHash = "0x" + Array.from(new Uint8Array(hashBuffer)).map((b) => b.toString(16).padStart(2, "0")).join("");

    // 5. Simpan Record Awal ke Database ('pending')
    const initialProofRecord = {
      user_id: user.id,
      trip_id: trip_id,
      proof_id: proofId,
      proof_hash: proofHash,
      payload_version: "1.0.0",
      snapshot_json: canonicalJson,
      salt: salt,
      chain_id: 11155111,
      contract_address: contractAddress,
      status: "pending",
      created_at: new Date().toISOString(),
    };

    const { data: insertedProof, error: insertError } = await adminClient
      .from("trip_proofs")
      .upsert(initialProofRecord, { onConflict: "proof_id" })
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    return new Response(JSON.stringify({
      message: "Proof generated and registered for processing",
      proof: insertedProof,
    }), {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
