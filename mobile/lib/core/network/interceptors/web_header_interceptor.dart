import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Interceptor для исправления проблем с заголовками на веб-платформе
/// Удаляет небезопасные заголовки, которые браузер не позволяет устанавливать вручную
class WebHeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Для веб-платформы удаляем заголовки, которые браузер управляет автоматически
    if (kIsWeb) {
      // Accept-Encoding - браузер управляет этим заголовком автоматически
      // Попытка установить его вручную вызывает предупреждение "Refused to set unsafe header"
      options.headers.remove('Accept-Encoding');
      options.headers.remove('accept-encoding'); // На случай разного регистра
      
      // Также удаляем другие небезопасные заголовки, которые браузер может блокировать
      options.headers.remove('Connection');
      options.headers.remove('connection');
      options.headers.remove('Host');
      options.headers.remove('host');
      options.headers.remove('Referer');
      options.headers.remove('referer');
      options.headers.remove('User-Agent');
      options.headers.remove('user-agent');
    }
    
    handler.next(options);
  }
}

