import '../datasources/remote/telegram_remote_datasource.dart';
import '../models/telegram_config.dart';

class TelegramRepository {
  final TelegramRemoteDataSource _remote;

  TelegramRepository(this._remote);

  Future<TelegramConfig> getConfig() => _remote.getConfig();
  Future<TelegramConfig> saveConfig(TelegramConfig config) =>
      _remote.saveConfig(config);
  Future<void> test({required String botToken, required String chatId}) =>
      _remote.test(botToken: botToken, chatId: chatId);
}
