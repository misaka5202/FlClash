import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('PatchClashConfig SNI fields', () {
    test('defaults are empty', () {
      expect(defaultClashConfig.sniMimic, isEmpty);
      expect(defaultClashConfig.sniMitm, isFalse);
      expect(defaultClashConfig.cealingRules, isEmpty);
    });

    test('cealing-rules round-trips under the core key', () {
      final json = {
        'cealing-rules': [
          [
            ['*pixiv.net', '*fanbox.cc'],
            'pixivision.net',
            '210.140.92.187',
          ],
          [
            ['*.googlevideo.com'],
            null,
            '',
          ],
        ],
        'sni-mimic': {'pixiv.net': 'fanbox.cc'},
        'sni-mitm': true,
      };
      final config = PatchClashConfig.fromJson(json);
      expect(config.cealingRules, hasLength(2));
      expect(config.sniMimic, {'pixiv.net': 'fanbox.cc'});
      expect(config.sniMitm, isTrue);

      final encoded = config.toJson();
      expect(encoded['cealing-rules'], json['cealing-rules']);
      expect(encoded['sni-mimic'], json['sni-mimic']);
      expect(encoded['sni-mitm'], isTrue);
    });

    test('a null fake SNI survives encoding as null', () {
      final config = PatchClashConfig.fromJson({
        'cealing-rules': [
          [
            ['*.googlevideo.com'],
            null,
            '',
          ],
        ],
      });
      final entry = config.toJson()['cealing-rules'] as List;
      expect((entry.first as List)[1], isNull);
    });

    test('malformed values fall back to the safe default', () {
      final config = PatchClashConfig.safeFormJson({'port': 'not-a-number'});
      expect(config, defaultClashConfig);
    });
  });
}
