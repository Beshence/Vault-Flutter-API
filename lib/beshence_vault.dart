import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:universal_io/io.dart';

class BeshenceVaultInfo {
  final String hello;
  final String apiVersion;

  BeshenceVaultInfo({required this.hello, required this.apiVersion});
}

class BeshenceVaultException implements Exception {
  int httpCode;
  int code;
  String name;
  String description;
  Response<dynamic>? response;

  BeshenceVaultException({required this.httpCode, required this.code, required this.name, required this.description, required this.response});

  BeshenceVaultException.fromResponse(this.response) :
        httpCode = response!.statusCode ?? 0,
        code = response.data["error"]["code"],
        name = response.data["error"]["name"],
        description = response.data["error"]["description"];

  BeshenceVaultException.malformedResponse(this.response) :
        httpCode = response!.statusCode ?? 0,
        code = 0,
        name = "malformed_response",
        description = "Server sent unexpected response.";

  BeshenceVaultException.dioException() : httpCode = 0,
        code = 0,
        name = "connection_error",
        description = "We couldn't contact server.",
        response = null;
}

class BeshenceVault {
  final String address;
  final String? token;
  late final Dio dio;

  BeshenceVault({required this.address, this.token}) {
    dio = _getDio(token: token);
  }

  Future<BeshenceVaultInfo> get vaultInfo async {
    try {
      final response = (await dio.get('https://$address/api/hello'));
      final data = response.data;
      if (response.statusCode != 200) {
        throw BeshenceVaultException.fromResponse(response);
      }
      if(data["response"]["hello"] != "Hi!") {
        throw BeshenceVaultException.malformedResponse(response);
      }
      return BeshenceVaultInfo(
          hello: data["response"]["hello"],
          apiVersion: data["response"]["api_version"]
      );
    } on DioException {
      throw BeshenceVaultException.dioException();
    }
  }

  Future<String> initChain(String chainName, {bool ignoreAlreadyInitialized = false}) async {
    // we'll use it later for api versioning
    BeshenceVaultInfo vaultInfo = await this.vaultInfo;

    try {
      final response = await dio.post('https://$address/api/v1.0/chain/$chainName', data: {});
      final data = response.data;
      if(response.statusCode != 201) {
        if (data["error"]["name"] == "chain_already_initialized" &&
            ignoreAlreadyInitialized) {
          return chainName;
        }
        throw BeshenceVaultException.fromResponse(response);
      }
      return data["response"]["chain_name"];
    } on DioException {
      throw BeshenceVaultException.dioException();
    }
  }

  BeshenceChain getChain(String chainName) => BeshenceChain(vault: this, chainName: chainName);
}

class BeshenceChain {
  final BeshenceVault vault;
  final String chainName;

  BeshenceChain({required this.vault, required this.chainName});

  Future<String?> get lastEventId async {
    // we'll use it later for api versioning
    BeshenceVaultInfo vaultInfo = await vault.vaultInfo;

    try {
      final response = await vault.dio.get("https://${vault.address}/api/v1.0/chain/$chainName/last");
      final data = response.data;
      if(response.statusCode != 200) {
        if(data["error"]["name"] == "no_events") return null;
        throw BeshenceVaultException.fromResponse(response);
      }
      return data["response"]["last"];
    } on DioException {
      throw BeshenceVaultException.dioException();
    }
  }

  Future<dynamic> getEvent(String eventId) async {
    // we'll use it later for api versioning
    BeshenceVaultInfo vaultInfo = await vault.vaultInfo;

    try {
      final response = await vault.dio.get("https://${vault.address}/api/v1.0/chain/$chainName/event/$eventId");
      final data = response.data;
      if(response.statusCode != 200) {
        throw BeshenceVaultException.fromResponse(response);
      }
      return data["response"]["event"];
    } on DioException {
      throw BeshenceVaultException.dioException();
    }
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
