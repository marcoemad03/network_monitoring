import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/telegram_remote_datasource.dart';
import '../../../data/models/telegram_config.dart';
import '../../../data/repositories/telegram_repository.dart';

final telegramRepositoryProvider = Provider<TelegramRepository>(
  (ref) => TelegramRepository(
    TelegramRemoteDataSource(ref.watch(dioProvider)),
  ),
);

final telegramConfigProvider =
    AsyncNotifierProvider<TelegramConfigController, TelegramConfig>(
      TelegramConfigController.new,
    );

class TelegramConfigController extends AsyncNotifier<TelegramConfig> {
  @override
  Future<TelegramConfig> build() {
    return ref.watch(telegramRepositoryProvider).getConfig();
  }

  Future<bool> save(TelegramConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(telegramRepositoryProvider).saveConfig(config),
    );
    return !state.hasError;
  }

  Future<String?> test({
    required String botToken,
    required String chatId,
  }) async {
    try {
      await ref.read(telegramRepositoryProvider).test(
        botToken: botToken,
        chatId: chatId,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
