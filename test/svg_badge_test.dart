import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('badge SVGs load and parse without errors', () async {
    // loadBytes runs the full flutter_svg parse/compile pipeline and throws
    // if the asset is missing or the SVG contains unsupported markup.
    await const SvgAssetLoader('assets/icons/host_badge.svg').loadBytes(null);
    await const SvgAssetLoader('assets/icons/hot_now_badge.svg')
        .loadBytes(null);
  });
}
