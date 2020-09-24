import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_selector/image_selector.dart';

void main() {
  const MethodChannel channel = MethodChannel('image_selector');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
//    expect(await ImageSelector.platformVersion, '42');
  });
}
