import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/network/api_client.dart';

void main() {
  test('API base URL is read from environment and normalized', () {
    dotenv.loadFromString(
      envString: 'BASE_URL=http://192.168.0.159:8990/api/v1/',
    );

    expect(resolveApiBaseUrl(), 'http://192.168.0.159:8990');
  });
}
