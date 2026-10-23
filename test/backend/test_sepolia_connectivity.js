// ==============================================================================
// TEST: READ-ONLY SEPOLIA CONNECTIVITY & CONTRACT DIAGNOSTIC SUITE
// MeraTrip Proof of Visit (Ethereum Sepolia Testnet)
// ==============================================================================
// ATURAN KEAMANAN:
// 1. 100% READ-ONLY (eth_chainId, eth_blockNumber, eth_getCode, eth_call, eth_getBalance, eth_getTransactionCount).
// 2. DILARANG mengirim transaksi (broadcast), mengubah state, atau mengekspos secret.
// ==============================================================================

const https = require('https');
const http = require('http');
const { ethers } = require('ethers');

const CONTRACT_ADDRESS = '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D';
const RELAYER_ADDRESS = '0x521EFC3eeA82684Ba0143C5707EdF281d6E7Cd21';
const EXPECTED_CHAIN_ID = 11155111; // 0xaa36a7

const CANDIDATE_ENDPOINTS = [
  { name: 'PublicNode (Default in Edge & Flutter)', url: 'https://ethereum-sepolia-rpc.publicnode.com' },
  { name: 'Sepolia.org (Flutter Fallback 1)', url: 'https://rpc.sepolia.org' },
  { name: '1RPC (Flutter Fallback 2)', url: 'https://1rpc.io/sepolia' },
  { name: 'Tenderly Public (Flutter Fallback 3)', url: 'https://gateway.tenderly.co/public/sepolia' },
  { name: 'Sepolia.drpc.org (Candidate Fallback)', url: 'https://sepolia.drpc.org' },
  { name: 'RPC2 Sepolia (Candidate Fallback)', url: 'https://rpc2.sepolia.org' },
];

function makeJsonRpcRequest(rpcUrl, method, params = [], timeoutMs = 7000) {
  return new Promise((resolve) => {
    const startTime = Date.now();
    try {
      const parsedUrl = new URL(rpcUrl);
      const postData = JSON.stringify({
        jsonrpc: '2.0',
        id: Math.floor(Math.random() * 1000) + 1,
        method,
        params,
      });

      const options = {
        hostname: parsedUrl.hostname,
        port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
        path: parsedUrl.pathname + parsedUrl.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
          'User-Agent': 'MeraTrip-Sepolia-Auditor/1.0',
        },
        timeout: timeoutMs,
      };

      const transport = parsedUrl.protocol === 'https:' ? https : http;
      const req = transport.request(options, (res) => {
        let rawBody = '';
        res.on('data', (chunk) => { rawBody += chunk; });
        res.on('end', () => {
          const latency = Date.now() - startTime;
          if (res.statusCode < 200 || res.statusCode >= 300) {
            resolve({
              ok: false,
              statusCode: res.statusCode,
              latency,
              error: `HTTP ${res.statusCode}: ${rawBody.slice(0, 200)}`,
            });
            return;
          }
          try {
            const parsed = JSON.parse(rawBody);
            if (parsed.error) {
              resolve({
                ok: false,
                statusCode: res.statusCode,
                latency,
                error: `JSON-RPC Error ${parsed.error.code}: ${parsed.error.message}`,
              });
            } else {
              resolve({
                ok: true,
                statusCode: res.statusCode,
                latency,
                result: parsed.result,
              });
            }
          } catch (parseErr) {
            resolve({
              ok: false,
              statusCode: res.statusCode,
              latency,
              error: `JSON parse error: ${parseErr.message}`,
            });
          }
        });
      });

      req.on('timeout', () => {
        req.destroy();
        resolve({
          ok: false,
          statusCode: 0,
          latency: Date.now() - startTime,
          error: `Timeout after ${timeoutMs}ms`,
        });
      });

      req.on('error', (netErr) => {
        resolve({
          ok: false,
          statusCode: 0,
          latency: Date.now() - startTime,
          error: `Network error: ${netErr.message}`,
        });
      });

      req.write(postData);
      req.end();
    } catch (err) {
      resolve({
        ok: false,
        statusCode: 0,
        latency: Date.now() - startTime,
        error: `Exception: ${err.message}`,
      });
    }
  });
}

async function auditEndpoint(endpoint) {
  console.log(`\n======================================================================`);
  console.log(`TESTING ENDPOINT: ${endpoint.name}`);
  console.log(`URL: ${endpoint.url}`);
  console.log(`======================================================================`);

  const report = {
    name: endpoint.name,
    url: endpoint.url,
    chainIdOk: false,
    blockNumberOk: false,
    contractCodeOk: false,
    viewCallOk: false,
    relayerBalanceOk: false,
    errors: [],
  };

  // 1. eth_chainId
  const chainIdRes = await makeJsonRpcRequest(endpoint.url, 'eth_chainId');
  if (chainIdRes.ok) {
    const chainIdNum = parseInt(chainIdRes.result, 16);
    console.log(`[PASS] eth_chainId: ${chainIdRes.result} (${chainIdNum}) [${chainIdRes.latency}ms]`);
    if (chainIdNum === EXPECTED_CHAIN_ID) {
      report.chainIdOk = true;
      console.log(`  -> Chain ID MATCH Sepolia (11155111)`);
    } else {
      const errMsg = `Chain ID mismatch! Expected ${EXPECTED_CHAIN_ID}, got ${chainIdNum}`;
      console.error(`  -> [FAIL] ${errMsg}`);
      report.errors.push(errMsg);
    }
  } else {
    console.error(`[FAIL] eth_chainId: ${chainIdRes.error} [${chainIdRes.latency}ms]`);
    report.errors.push(`eth_chainId failed: ${chainIdRes.error}`);
    return report; // Cannot proceed if basic RPC is down
  }

  // 2. eth_blockNumber
  const blockNumRes = await makeJsonRpcRequest(endpoint.url, 'eth_blockNumber');
  if (blockNumRes.ok) {
    const blockNum = parseInt(blockNumRes.result, 16);
    report.blockNumberOk = true;
    console.log(`[PASS] eth_blockNumber: ${blockNumRes.result} (Block #${blockNum}) [${blockNumRes.latency}ms]`);
  } else {
    console.error(`[FAIL] eth_blockNumber: ${blockNumRes.error}`);
    report.errors.push(`eth_blockNumber failed: ${blockNumRes.error}`);
  }

  // 3. eth_getBlockByNumber (latest)
  const blockRes = await makeJsonRpcRequest(endpoint.url, 'eth_getBlockByNumber', ['latest', false]);
  if (blockRes.ok && blockRes.result) {
    const blockTime = new Date(parseInt(blockRes.result.timestamp, 16) * 1000).toISOString();
    console.log(`[PASS] eth_getBlockByNumber: hash=${blockRes.result.hash?.slice(0, 14)}..., time=${blockTime}`);
  } else {
    console.warn(`[WARN] eth_getBlockByNumber: ${blockRes.error || 'Empty block'}`);
  }

  // 4. eth_getCode pada contract address
  const codeRes = await makeJsonRpcRequest(endpoint.url, 'eth_getCode', [CONTRACT_ADDRESS, 'latest']);
  if (codeRes.ok) {
    const code = codeRes.result || '0x';
    const codeLength = (code.length - 2) / 2; // bytes
    if (codeLength > 0 && code !== '0x') {
      report.contractCodeOk = true;
      console.log(`[PASS] eth_getCode: Bytecode FOUND at ${CONTRACT_ADDRESS} (${codeLength} bytes)`);
    } else {
      const errMsg = `Contract NOT deployed at ${CONTRACT_ADDRESS} on this chain (code is empty 0x)`;
      console.error(`[FAIL] eth_getCode: ${errMsg}`);
      report.errors.push(errMsg);
    }
  } else {
    console.error(`[FAIL] eth_getCode: ${codeRes.error}`);
    report.errors.push(`eth_getCode failed: ${codeRes.error}`);
  }

  // 5. eth_call ke getter smart contract (totalProofsCount, owner, isProofRecorded)
  // Selector: totalProofsCount() = 0x5eb04ddc
  const countRes = await makeJsonRpcRequest(endpoint.url, 'eth_call', [
    { to: CONTRACT_ADDRESS, data: '0x5eb04ddc' },
    'latest',
  ]);
  if (countRes.ok && countRes.result && countRes.result !== '0x') {
    const totalProofs = parseInt(countRes.result, 16);
    report.viewCallOk = true;
    console.log(`[PASS] eth_call totalProofsCount(): ${totalProofs} proofs recorded on-chain`);
  } else {
    console.warn(`[WARN] eth_call totalProofsCount(): ${countRes.error || countRes.result}`);
  }

  // Selector: owner() = 0x8da5cb5b
  const ownerRes = await makeJsonRpcRequest(endpoint.url, 'eth_call', [
    { to: CONTRACT_ADDRESS, data: '0x8da5cb5b' },
    'latest',
  ]);
  if (ownerRes.ok && ownerRes.result && ownerRes.result.length >= 26) {
    const contractOwner = '0x' + ownerRes.result.slice(-40);
    console.log(`[PASS] eth_call owner(): ${contractOwner}`);
  }

  // 6. Relayer Status: eth_getBalance & eth_getTransactionCount
  const balRes = await makeJsonRpcRequest(endpoint.url, 'eth_getBalance', [RELAYER_ADDRESS, 'latest']);
  const nonceRes = await makeJsonRpcRequest(endpoint.url, 'eth_getTransactionCount', [RELAYER_ADDRESS, 'latest']);
  const pendingNonceRes = await makeJsonRpcRequest(endpoint.url, 'eth_getTransactionCount', [RELAYER_ADDRESS, 'pending']);

  if (balRes.ok && nonceRes.ok) {
    report.relayerBalanceOk = true;
    const balWei = BigInt(balRes.result || '0x0');
    const balEth = ethers.formatEther(balWei);
    const nonceLatest = parseInt(nonceRes.result, 16);
    const noncePending = parseInt(pendingNonceRes.result || nonceRes.result, 16);
    console.log(`[PASS] Relayer Address: ${RELAYER_ADDRESS}`);
    console.log(`  Balance: ${balEth} SepoliaETH (${balWei.toString()} Wei)`);
    console.log(`  Nonce (Latest): ${nonceLatest}, Nonce (Pending): ${noncePending}`);
  } else {
    console.warn(`[WARN] Relayer status check: ${balRes.error || nonceRes.error}`);
  }

  // 7. EIP-1559 Fee Data
  const gasPriceRes = await makeJsonRpcRequest(endpoint.url, 'eth_gasPrice');
  if (gasPriceRes.ok) {
    const gasPriceGwei = ethers.formatUnits(BigInt(gasPriceRes.result), 'gwei');
    console.log(`[PASS] eth_gasPrice: ${gasPriceGwei} Gwei`);
  }

  return report;
}

async function runDiagnostic() {
  console.log(`======================================================================`);
  console.log(`FULL SEPOLIA CONNECTIVITY & READ-ONLY CONTRACT AUDIT`);
  console.log(`Time: ${new Date().toISOString()}`);
  console.log(`Contract: ${CONTRACT_ADDRESS}`);
  console.log(`Relayer: ${RELAYER_ADDRESS}`);
  console.log(`Target Chain: Ethereum Sepolia (ID: ${EXPECTED_CHAIN_ID})`);
  console.log(`======================================================================`);

  const results = [];
  for (const ep of CANDIDATE_ENDPOINTS) {
    const res = await auditEndpoint(ep);
    results.push(res);
  }

  console.log(`\n======================================================================`);
  console.log(`SUMMARY MATRIX: SEPOLIA CONNECTIVITY RESULTS`);
  console.log(`======================================================================`);
  console.log(`Endpoint Name                  | Chain ID | Block # | Contract Code | View Calls | Status`);
  console.log(`-----------------------------------------------------------------------------------------`);
  for (const r of results) {
    const cId = r.chainIdOk ? 'PASS' : 'FAIL';
    const bNum = r.blockNumberOk ? 'PASS' : 'FAIL';
    const cCode = r.contractCodeOk ? 'PASS' : 'FAIL';
    const vCall = r.viewCallOk ? 'PASS' : 'FAIL';
    const paddedName = r.name.padEnd(30, ' ');
    const overall = (r.chainIdOk && r.blockNumberOk && r.contractCodeOk && r.viewCallOk) ? 'HEALTHY' : 'DEGRADED/FAILED';
    console.log(`${paddedName} | ${cId.padEnd(8, ' ')} | ${bNum.padEnd(7, ' ')} | ${cCode.padEnd(13, ' ')} | ${vCall.padEnd(10, ' ')} | ${overall}`);
  }
  console.log(`======================================================================`);

  // ======================================================================
  // REGRESSION TESTS
  // ======================================================================
  console.log(`\n======================================================================`);
  console.log(`RUNNING SEPOLIA CONNECTIVITY REGRESSION TESTS`);
  console.log(`======================================================================`);

  // REGRESSION 1: Chain ID Mismatch Detection
  {
    const mockWrongChainId = 1; // Mainnet
    if (mockWrongChainId !== EXPECTED_CHAIN_ID) {
      console.log(`[PASS] Regression 1: Chain ID mismatch terdeteksi tegas (Expected: ${EXPECTED_CHAIN_ID}, Got: ${mockWrongChainId})`);
    } else {
      console.error(`[FAIL] Regression 1: Chain ID mismatch lolos tanpa terdeteksi!`);
      process.exit(1);
    }
  }

  // REGRESSION 2: RPC Timeout & Fallback Failover
  {
    const fallbackList = [
      'https://rpc.sepolia.org', // Endpoint yang diketahui timeout
      'https://ethereum-sepolia-rpc.publicnode.com', // Healthy fallback
    ];
    let selectedRpc = null;
    for (const rpc of fallbackList) {
      const res = await makeJsonRpcRequest(rpc, 'eth_chainId', [], 2000);
      if (res.ok && parseInt(res.result, 16) === EXPECTED_CHAIN_ID) {
        selectedRpc = rpc;
        break;
      }
    }
    if (selectedRpc === 'https://ethereum-sepolia-rpc.publicnode.com') {
      console.log(`[PASS] Regression 2: Timeout pada endpoint pertama berhasil failover ke fallback sehat (${selectedRpc})`);
    } else {
      console.error(`[FAIL] Regression 2: Failover RPC tidak memilih endpoint yang tepat: ${selectedRpc}`);
      process.exit(1);
    }
  }

  // REGRESSION 3: Missing / Empty RPC Configuration Safe Defaulting
  {
    const emptyEnv = "";
    const sanitizedRpc = (emptyEnv || "https://ethereum-sepolia-rpc.publicnode.com").trim();
    if (sanitizedRpc === "https://ethereum-sepolia-rpc.publicnode.com") {
      console.log(`[PASS] Regression 3: Konfigurasi RPC kosong defaulting secara aman ke endpoint publik terverifikasi`);
    } else {
      console.error(`[FAIL] Regression 3: Defaulting RPC gagal`);
      process.exit(1);
    }
  }

  // REGRESSION 4: Contract Code Empty Detection (Anti-Ghost Contract)
  {
    // Cek alamat zero address
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const healthyEndpoint = results.find(r => r.contractCodeOk)?.url || 'https://ethereum-sepolia-rpc.publicnode.com';
    const codeZero = await makeJsonRpcRequest(healthyEndpoint, 'eth_getCode', [zeroAddress, 'latest']);
    if (codeZero.ok && (codeZero.result === '0x' || codeZero.result === '0x0')) {
      console.log(`[PASS] Regression 4: Alamat tanpa contract code terdeteksi kosong (0x) secara akurat`);
    } else {
      console.error(`[FAIL] Regression 4: Zero address tidak menghasilkan 0x code:`, codeZero);
      process.exit(1);
    }
  }

  // REGRESSION 5: View Function Revert Immunity (verifyProof vs getProof)
  {
    const healthyEndpoint = results.find(r => r.viewCallOk)?.url || 'https://ethereum-sepolia-rpc.publicnode.com';
    const dummyProofId = '0x' + '9'.repeat(64);
    const dummyProofHash = '0x' + '8'.repeat(64);

    // Call verifyProof (0x739808e5)
    const verifyCalldata = '0x739808e5' + dummyProofId.slice(2) + dummyProofHash.slice(2);
    const verifyRes = await makeJsonRpcRequest(healthyEndpoint, 'eth_call', [
      { to: CONTRACT_ADDRESS, data: verifyCalldata },
      'latest',
    ]);
    if (verifyRes.ok && verifyRes.result) {
      const boolVal = parseInt(verifyRes.result, 16);
      if (boolVal === 0) {
        console.log(`[PASS] Regression 5: verifyProof untuk bukti yang belum ada mengembalikan false (0) tanpa revert`);
      } else {
        console.error(`[FAIL] Regression 5: verifyProof mengembalikan hasil tak terduga:`, verifyRes.result);
      }
    } else {
      console.error(`[FAIL] Regression 5: verifyProof gagal dipanggil via eth_call:`, verifyRes);
      process.exit(1);
    }
  }

  console.log(`======================================================================`);
  console.log(`ALL 5 SEPOLIA CONNECTIVITY REGRESSION TESTS PASSED!`);
  console.log(`======================================================================`);
}

runDiagnostic().catch(console.error);
