import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:product_traceability_mobile/core/constants/abi.dart';

class Web3Service {
  late Web3Client _client;
  final _storage = const FlutterSecureStorage();
  Credentials? _credentials;
  DeployedContract? _contract;

  Web3Service() {
    _init();
  }

  Future<void> _init() async {
    // For Android emulator use 10.0.2.2, for iOS/Physical device use your computer's IP
    // const rpcUrl = "http://10.0.2.2:8545"; 
    const rpcUrl = "http://192.168.1.47:8545"; // Updated to your current Local IP 
    _client = Web3Client(rpcUrl, Client());
    await _loadContract();
    await _loadPrivateKey();
  }

  Future<void> _loadContract() async {
    final contractAddr = EthereumAddress.fromHex(AppConstants.contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(AppConstants.contractAbi.toString(), 'ProductTraceability'),
      contractAddr,
    );
  }

  Future<void> _loadPrivateKey() async {
    final privateKey = await _storage.read(key: 'private_key');
    if (privateKey != null) {
      _credentials = EthPrivateKey.fromHex(privateKey);
    }
  }

  Future<String> createWallet() async {
    final rng = null; // defaults to secure random
    final credentials = EthPrivateKey.createRandom(rng);
    final privateKey = '0x${credentials.privateKeyInt.toRadixString(16)}';
    await _storage.write(key: 'private_key', value: privateKey);
    _credentials = credentials;
    return privateKey;
  }

  Future<void> importWallet(String privateKey) async {
    _credentials = EthPrivateKey.fromHex(privateKey);
    await _storage.write(key: 'private_key', value: privateKey);
  }

  Future<EthereumAddress?> getAddress() async {
    return _credentials?.address;
  }

  Future<EtherAmount> getBalance() async {
    if (_credentials == null) return EtherAmount.zero();
    return await _client.getBalance(_credentials!.address);
  }

  // Contract Calls
  Future<String> createProduct(String productId, String location) async {
    return _writeContract('createProduct', [productId, location]);
  }

  Future<String> addRetailerHop(String productId, String location) async {
    return _writeContract('addRetailerHop', [productId, location]);
  }

  Future<List<dynamic>> getProduct(String productId) async {
    return _readContract('getProduct', [productId]);
  }

  Future<bool> isManufacturer(EthereumAddress address) async {
    final result = await _readContract('isManufacturer', [address]);
    return result.first as bool;
  }

  Future<bool> isRetailer(EthereumAddress address) async {
    final result = await _readContract('isRetailer', [address]);
    return result.first as bool;
  }

  Future<String> _writeContract(String functionName, List<dynamic> args) async {
    if (_credentials == null || _contract == null) throw Exception("Wallet/Contract not loaded");
    final function = _contract!.function(functionName);
    
    return await _client.sendTransaction(
      _credentials!,
      Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: args,
      ),
      chainId: 31337, // Hardhat Localhost ChainID
    );
  }

  Future<List<dynamic>> _readContract(String functionName, List<dynamic> args) async {
    if (_contract == null) throw Exception("Contract not loaded");
    final function = _contract!.function(functionName);
    return await _client.call(
      contract: _contract!,
      function: function,
      params: args,
    );
  }
}
