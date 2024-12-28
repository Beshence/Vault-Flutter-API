import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:universal_io/io.dart';

class BeshenceVaultInfo {
  final String hello;
  final String apiVersion;

  BeshenceVaultInfo({required this.hello, required this.apiVersion});
}

class BeshenceVault {
  final String address;
  final String? token;
  late final Dio dio;

  BeshenceVault({required this.address, this.token}) {
    dio = _getDio(token: token);
  }

  Future<BeshenceVaultInfo> getVaultInfo() async {
    final serverHelloResponse = (await dio.get('https://$address/api/hello'));
    print(serverHelloResponse.data);
    return BeshenceVaultInfo(
        hello: serverHelloResponse.data["response"]["hello"],
        apiVersion: serverHelloResponse.data["response"]["api_version"]
    );
  }
}

Dio _getDio({String? token}) {
  final dio = Dio();

  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    // TODO: change it
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  };

  dio.options.headers = {
    if (token != null) "Authorization": "Bearer $token"
  };
  dio.options.validateStatus = (code) => true;

  return dio;
}
