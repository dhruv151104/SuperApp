import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/services/web3_service.dart';
import 'package:product_traceability_mobile/services/api_service.dart';

final web3ServiceProvider = Provider<Web3Service>((ref) {
  return Web3Service();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
