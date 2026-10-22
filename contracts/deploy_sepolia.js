/**
 * Script Deployment Smart Contract MeraTripProof ke Ethereum Sepolia
 *
 * FITUR KEAMANAN:
 * 1. Tidak pernah mencetak private key atau secret ke log/terminal.
 * 2. Memvalidasi Chain ID (wajib 11155111 - Sepolia) sebelum transaksi dikirim.
 * 3. Memeriksa saldo wallet relayer dan menghitung estimasi biaya gas.
 * 4. Membutuhkan flag eksplisit `--confirm` untuk mengirim transaksi broadcast.
 *    Jika dijalankan tanpa `--confirm`, script hanya melakukan pre-flight check aman.
 * 5. Menunggu mining receipt (status 1) dan memverifikasi bytecode on-chain.
 */

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

const EXPECTED_CHAIN_ID = 11155111n; // Ethereum Sepolia
const SEPOLIA_RPC = process.env.SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com';
const PRIVATE_KEY = process.env.RELAYER_PRIVATE_KEY;
const CONTRACT_CONFIG_PATH = path.join(__dirname, 'MeraTripProof.json');

const isConfirmMode = process.argv.includes('--confirm');

async function main() {
  console.log('================================================================');
  console.log('       MERATRIP - ETHEREUM SEPOLIA DEPLOYMENT MANAGER           ');
  console.log('================================================================');

  // 1. Validasi Artifact Kompilasi
  if (!fs.existsSync(CONTRACT_CONFIG_PATH)) {
    console.error('[ERROR] File MeraTripProof.json tidak ditemukan.');
    console.error('Silakan jalankan `npm run compile` terlebih dahulu.');
    process.exit(1);
  }

  const contractConfig = JSON.parse(fs.readFileSync(CONTRACT_CONFIG_PATH, 'utf8'));
  const abi = contractConfig.abi;
  const bytecode = contractConfig.bytecode;

  if (!bytecode || bytecode === '0x' || bytecode.length < 10) {
    console.error('[ERROR] Bytecode kontrak belum tersedia di MeraTripProof.json.');
    console.error('Silakan jalankan `npm run compile` untuk mengompilasi source code Solidity.');
    process.exit(1);
  }

  // 2. Koneksi ke RPC Provider
  console.log(`[1/5] Menghubungkan ke RPC Node: ${SEPOLIA_RPC}`);
  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC);

  let network;
  try {
    network = await provider.getNetwork();
  } catch (err) {
    console.error(`[ERROR] Gagal terhubung ke RPC Endpoint: ${err.message}`);
    process.exit(1);
  }

  console.log(`      Network Name: ${network.name}`);
  console.log(`      Chain ID Terdeteksi: ${network.chainId.toString()}`);

  // 3. Validasi Keamanan Chain ID (Wajib Sepolia)
  if (network.chainId !== EXPECTED_CHAIN_ID) {
    console.error(`[ABORT] Keamanan Ditegakkan: Chain ID (${network.chainId}) bukan Ethereum Sepolia (11155111)!`);
    console.error('Pengiriman transaksi dibatalkan untuk mencegah kesalahan deployment.');
    process.exit(1);
  }
  console.log('      [OK] Validasi Chain ID Sepolia (11155111) Sukses.');

  // 4. Validasi Wallet Relayer
  console.log('\n[2/5] Memeriksa Kredensial Wallet Relayer...');
  if (!PRIVATE_KEY || PRIVATE_KEY.trim() === '') {
    console.log('      [INFO] RELAYER_PRIVATE_KEY belum di-set di environment.');
    console.log('\nPanduan menjalankan deployment di Windows PowerShell:');
    console.log('  1. Dapatkan saldo testnet gratis dari https://cloud.google.com/application/web3/faucet/ethereum/sepolia');
    console.log('  2. Set environment variable di terminal aktif:');
    console.log('     $env:RELAYER_PRIVATE_KEY="0x<private_key_wallet_testnet_anda>"');
    console.log('     $env:SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"');
    console.log('  3. Jalankan pre-flight check:');
    console.log('     node contracts/deploy_sepolia.js');
    console.log('  4. Jika saldo cukup dan siap deploy, tambahkan flag --confirm:');
    console.log('     node contracts/deploy_sepolia.js --confirm');
    process.exit(0);
  }

  let wallet;
  try {
    wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  } catch (err) {
    console.error('[ERROR] Format RELAYER_PRIVATE_KEY tidak valid. Pastikan diawali 0x dan 64 hex characters.');
    process.exit(1);
  }

  // Tampilkan hanya public address (TIDAK PERNAH menampilkan private key)
  console.log(`      Alamat Publik Relayer: ${wallet.address}`);

  const balance = await provider.getBalance(wallet.address);
  const balanceEth = ethers.formatEther(balance);
  console.log(`      Saldo Wallet: ${balanceEth} SepoliaETH`);

  // 5. Estimasi Gas & Biaya Deployment
  console.log('\n[3/5] Menghitung Estimasi Gas & Biaya Deployment...');
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const deployTx = await factory.getDeployTransaction();

  let estimatedGas;
  try {
    estimatedGas = await provider.estimateGas(deployTx);
  } catch (err) {
    console.warn(`[WARNING] Gagal estimasi gas otomatis: ${err.message}. Menggunakan default fallback 850,000 unit.`);
    estimatedGas = 850000n;
  }

  const feeData = await provider.getFeeData();
  const gasPrice = feeData.gasPrice || ethers.parseUnits('1', 'gwei');
  const maxFeePerGas = feeData.maxFeePerGas || gasPrice;
  const maxPriorityFee = feeData.maxPriorityFeePerGas || ethers.parseUnits('0.1', 'gwei');

  // Gunakan maxFeePerGas untuk estimasi batas atas EIP-1559 yang akurat
  const estimatedCostWei = estimatedGas * maxFeePerGas;
  const estimatedCostGwei = ethers.formatUnits(estimatedCostWei, 'gwei');
  const estimatedCostEth = ethers.formatEther(estimatedCostWei);

  // Estimasi skenario konservatif jika jaringan Sepolia mengalami lonjakan ke 2 Gwei
  const conservativeCostWei = estimatedGas * ethers.parseUnits('2', 'gwei');
  const conservativeCostEth = ethers.formatEther(conservativeCostWei);

  console.log(`      Estimasi Gas Limit         : ${estimatedGas.toString()} unit`);
  console.log(`      Base Gas Price             : ${gasPrice.toString()} wei (${ethers.formatUnits(gasPrice, 'gwei')} Gwei)`);
  console.log(`      Max Fee Per Gas (EIP-1559) : ${maxFeePerGas.toString()} wei (${ethers.formatUnits(maxFeePerGas, 'gwei')} Gwei)`);
  console.log(`      Max Priority Fee (Tip)     : ${maxPriorityFee.toString()} wei (${ethers.formatUnits(maxPriorityFee, 'gwei')} Gwei)`);
  console.log(`      Estimasi Biaya Transaksi   : ${estimatedCostWei.toString()} wei (~${estimatedCostGwei} Gwei / ~${estimatedCostEth} SepoliaETH)`);
  console.log(`      Batas Aman (Buffer 2 Gwei) : ~${conservativeCostEth} SepoliaETH (Skenario jika terjadi spike)`);

  if (balance < estimatedCostWei) {
    console.error('\n[ABORT] Saldo wallet TIDAK MENCUKUPI untuk membayar gas transaksi!');
    console.error(`Dibutuhkan minimal ~${estimatedCostEth} SepoliaETH, namun saldo Anda ${balanceEth} SepoliaETH.`);
    console.error('Silakan isi saldo melalui faucet Sepolia terlebih dahulu.');
    process.exit(1);
  }
  console.log('      [OK] Saldo sangat mencukupi untuk deployment.');

  // 6. Cek Mode Konfirmasi Transaksi
  console.log('\n[4/5] Memeriksa Mode Eksekusi...');
  if (!isConfirmMode) {
    console.log('      [MODE PRE-FLIGHT CHECK]: Transaksi BELUM dikirim.');
    console.log('      Semua persyaratan (RPC, Chain ID, Saldo, Bytecode) telah TERVERIFIKASI AMAN.');
    console.log('\n>>> UNTUK MENGIRIM TRANSAKSI BROADCAST KE SEPOLIA, JALANKAN:');
    console.log('    node contracts/deploy_sepolia.js --confirm\n');
    process.exit(0);
  }

  // 7. Eksekusi Deployment Sungguhan (Hanya jika --confirm disertakan)
  console.log('      [MODE BROADCAST AKTIF]: Mengirim transaksi deployment ke Sepolia mempool...');
  const contract = await factory.deploy();
  const txHash = contract.deploymentTransaction().hash;
  console.log(`      TX Hash Broadcast: ${txHash}`);
  console.log(`      Explorer Link: https://sepolia.etherscan.io/tx/${txHash}`);
  console.log('      Menunggu konfirmasi penambangan blok (mining)...');

  await contract.waitForDeployment();
  const deployedAddress = await contract.getAddress();
  const receipt = await contract.deploymentTransaction().wait();

  // 8. Verifikasi Bytecode On-Chain
  console.log('\n[5/5] Memverifikasi Keberadaan Bytecode On-Chain...');
  const onChainCode = await provider.getCode(deployedAddress);
  const isVerifiedOnChain = onChainCode !== '0x' && onChainCode.length > 10;

  if (!isVerifiedOnChain || receipt.status !== 1) {
    console.error('[GAGAL] Transaksi selesai tetapi bytecode tidak ditemukan pada alamat tersebut.');
    process.exit(1);
  }

  console.log('================================================================');
  console.log('             DEPLOYMENT SEPOLIA BERHASIL (100% SUKSES)          ');
  console.log('================================================================');
  console.log(`Contract Name   : MeraTripProof`);
  console.log(`Network         : Ethereum Sepolia (Chain ID: 11155111)`);
  console.log(`Contract Address: ${deployedAddress}`);
  console.log(`Transaction Hash: ${txHash}`);
  console.log(`Block Number    : ${receipt.blockNumber}`);
  console.log(`Gas Digunakan   : ${receipt.gasUsed.toString()} unit`);
  console.log(`Block Explorer  : https://sepolia.etherscan.io/address/${deployedAddress}`);
  console.log('================================================================');
  console.log('\nLANGKAH MANUAL SELANJUTNYA UNTUK MEMPERBARUI PROJECT:');
  console.log('1. Perbarui `defaultContractAddress` pada `contracts/MeraTripProof.json` dengan:');
  console.log(`   "${deployedAddress}"`);
  console.log('2. Perbarui `defaultContractAddress` pada `lib/core/services/blockchain_service.dart` dengan:');
  console.log(`   static const String defaultContractAddress = '${deployedAddress}';`);
  console.log('3. Set secret CONTRACT_ADDRESS pada Supabase Edge Function:');
  console.log(`   supabase secrets set CONTRACT_ADDRESS="${deployedAddress}"`);
  console.log('================================================================\n');
}

main().catch((err) => {
  console.error('\n[FATAL ERROR]:', err.message);
  process.exit(1);
});
