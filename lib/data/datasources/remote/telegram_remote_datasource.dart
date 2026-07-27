import '../../../core/network/dio_client.dart';
import '../../models/telegram_config.dart';

class TelegramRemoteDataSource {
  final DioClient _client;

  TelegramRemoteDataSource(this._client);

  Future<TelegramConfig> getConfig() async {
    final response = await _client.get('/telegram/config');
    return TelegramConfig.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<TelegramConfig> saveConfig(TelegramConfig config) async {
    final response = await _client.put(
      '/telegram/config',
      data: config.toJson(),
    );
    return TelegramConfig.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<void> test({
    required String botToken,
    required String chatId,
  }) async {
    await _client.post('/telegram/test', data: {
      'bot_token': botToken,
      'chat_id': chatId,
    });
  }
}
