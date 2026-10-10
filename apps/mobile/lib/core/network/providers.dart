import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/auth_controller.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokens: ref.watch(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).sessionExpired(),
  );
});
