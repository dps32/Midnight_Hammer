import 'package:flutter_test/flutter_test.dart';

import 'package:client_flutter/app_data.dart';
import 'package:client_flutter/network_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppData can be created and disposed', () {
    final AppData appData = AppData(
      initialConfig: const NetworkConfig(
        serverOption: ServerOption.local,
        playerName: 'TestProbe',
      ),
    );
    expect(appData.phase, isNotNull);
    appData.dispose();
  });
}
