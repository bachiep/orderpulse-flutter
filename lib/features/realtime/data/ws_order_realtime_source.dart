import 'dart:async';

import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/network/token_storage.dart';
import 'package:orderpulse_flutter/features/realtime/data/order_realtime_event_dto.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_source.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live [WebSocketChannel]-backed order stream source.
class WsOrderRealtimeDataSource implements OrderRealtimeDataSource {
  WsOrderRealtimeDataSource({
    required AppConfig config,
    required TokenStorage tokenStorage,
    WebSocketChannel Function(Uri uri)? channelFactory,
  })  : _config = config,
        _tokenStorage = tokenStorage,
        _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final AppConfig _config;
  final TokenStorage _tokenStorage;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;

  @override
  Future<Stream<OrderRealtimeEvent>> connect() async {
    await disconnect();
    final tokens = await _tokenStorage.readTokens();
    final baseUri = Uri.parse(_config.wsBaseUrl);
    final uri = tokens != null && tokens.accessToken.isNotEmpty
        ? baseUri.replace(
            queryParameters: {
              ...baseUri.queryParameters,
              'token': tokens.accessToken,
            },
          )
        : baseUri;

    final channel = _channelFactory(uri);
    _channel = channel;
    await channel.ready;

    return channel.stream
        .map(OrderRealtimeEventDto.tryParse)
        .where((event) => event != null)
        .cast<OrderRealtimeEvent>();
  }

  @override
  Future<void> disconnect() async {
    final active = _channel;
    _channel = null;
    if (active != null) {
      await active.sink.close();
    }
  }
}
