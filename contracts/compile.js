/**
 * Script Kompilasi Solidity MeraTripProof
 * Mengompilasi contracts/MeraTripProof.sol menggunakan solc v0.8.20
 * dan menghasilkan ABI serta EVM Bytecode ke contracts/MeraTripProof.json.
 */

const fs = require('fs');
const path = require('path');
const solc = require('solc');

const contractFileName = 'MeraTripProof.sol';
const contractPath = path.join(__dirname, contractFileName);
const configPath = path.join(__dirname, 'MeraTripProof.json');

console.log('====================================================');
console.log('KOMPILASI SMART CONTRACT MERATRIPPROOF');
console.log('====================================================');
console.log(`Source File: ${contractPath}`);
console.log(`Solc Version: ${solc.version()}`);

if (!fs.existsSync(contractPath)) {
  console.error(`Error: File ${contractPath} tidak ditemukan.`);
  process.exit(1);
}

const sourceCode = fs.readFileSync(contractPath, 'utf8');

// Standar input JSON untuk compiler Solidity
const input = {
  language: 'Solidity',
  sources: {
    [contractFileName]: {
      content: sourceCode,
    },
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    outputSelection: {
      '*': {
        '*': ['abi', 'evm.bytecode', 'evm.deployedBytecode'],
      },
    },
  },
};

console.log('Sedang mengompilasi kontrak...');
const output = JSON.parse(solc.compile(JSON.stringify(input)));

// Periksa error kompilasi
let hasError = false;
if (output.errors) {
  for (const error of output.errors) {
    if (error.severity === 'error') {
      console.error(`[ERROR] ${error.formattedMessage}`);
      hasError = true;
    } else {
      console.warn(`[WARNING] ${error.formattedMessage}`);
    }
  }
}

if (hasError) {
  console.error('Kompilasi gagal dengan error di atas.');
  process.exit(1);
}

const contractData = output.contracts[contractFileName]['MeraTripProof'];
const abi = contractData.abi;
const bytecode = contractData.evm.bytecode.object;

console.log(`Kompilasi Berhasil!`);
console.log(`Ukuran Bytecode: ${bytecode.length / 2} bytes`);

// Periksa constructor arguments
const constructorItem = abi.find((item) => item.type === 'constructor');
const constructorInputs = constructorItem ? constructorItem.inputs : [];
console.log(`Constructor Parameters: ${constructorInputs.length} (Membutuhkan arguments: ${constructorInputs.length > 0})`);

// Baca konfigurasi lama jika ada untuk mempertahankan network & explorer metadata
let existingConfig = {};
if (fs.existsSync(configPath)) {
  try {
    existingConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch (_) {}
}

const updatedConfig = {
  contractName: 'MeraTripProof',
  network: existingConfig.network || 'Ethereum Sepolia Testnet',
  chainId: existingConfig.chainId || 11155111,
  sepoliaRpc: existingConfig.sepoliaRpc || 'https://ethereum-sepolia-rpc.publicnode.com',
  blockExplorer: existingConfig.blockExplorer || 'https://sepolia.etherscan.io',
  defaultContractAddress: existingConfig.defaultContractAddress || '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
  compilerVersion: solc.version(),
  compiledAt: new Date().toISOString(),
  bytecode: '0x' + bytecode,
  abi: abi,
};

fs.writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2), 'utf8');
console.log(`Artifact tersimpan di: ${configPath}`);
console.log('====================================================');
