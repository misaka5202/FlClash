import 'package:fl_clash/common/common.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeCealingRule', () {
    test('keeps a full triple', () {
      final rule = normalizeCealingRule([
        ['*pixiv.net', '*fanbox.cc'],
        'pixivision.net',
        '210.140.92.187',
      ]);
      expect(rule, [
        ['*pixiv.net', '*fanbox.cc'],
        'pixivision.net',
        '210.140.92.187',
      ]);
    });

    test('preserves null and empty fake SNI as distinct values', () {
      expect(
        normalizeCealingRule([
          ['*a.test'],
          null,
          '',
        ])![1],
        isNull,
      );
      expect(
        normalizeCealingRule([
          ['*b.test'],
          '',
          '1.1.1.1',
        ])![1],
        '',
      );
    });

    test('trims the address and rejects malformed entries', () {
      expect(
        normalizeCealingRule([
          ['*c.test'],
          'x.test',
          ' 9.9.9.9 ',
        ])![2],
        '9.9.9.9',
      );
      expect(normalizeCealingRule(['*d.test', 'x.test', '1.1.1.1']), isNull);
      expect(normalizeCealingRule([[], 'x.test', '1.1.1.1']), isNull);
      expect(
        normalizeCealingRule([
          [''],
          'x.test',
          '1.1.1.1',
        ]),
        isNull,
      );
      expect(
        normalizeCealingRule([
          ['*e.test'],
          5,
          '1.1.1.1',
        ]),
        isNull,
      );
      expect(
        normalizeCealingRule([
          ['*f.test'],
          'x.test',
          ['1.1.1.1'],
        ]),
        isNull,
      );
      expect(normalizeCealingRule(null), isNull);
    });
  });

  group('stripJsonComments', () {
    test('removes line and block comments outside strings', () {
      const source = '''
[
  [["*a.test"], "//not-a-comment", "1.1.1.1"], // trailing
  /* block
     comment */
  [["*b.test"], "x.test", "2.2.2.2"],
]''';
      final cleaned = stripJsonComments(source);
      expect(cleaned, contains('//not-a-comment'));
      expect(cleaned, isNot(contains('trailing')));
      expect(cleaned, isNot(contains('block')));
    });

    test('drops trailing commas', () {
      expect(
        stripJsonComments('[["a"], "b", "c",]').trim(),
        '[["a"], "b", "c"]',
      );
    });
  });

  group('parseCealingRules', () {
    test('parses a published-shaped document', () {
      final rules = parseCealingRules('''
[
    // pximg uses a generated SNI
    [["*pximg.net"],"","210.140.139.133"],
    [["gemini.google.com"],"g.cn","47.102.115.14"],
    [["*.googlevideo.com"],null,""],
    [["^*disabled.test"],"x.test","1.1.1.1"],
    "junk",
    [["bad"], "only-two-elements"],
]''');
      expect(rules, hasLength(4));
      expect(rules![0], [
        ['*pximg.net'],
        '',
        '210.140.139.133',
      ]);
      expect(rules[2], [
        ['*.googlevideo.com'],
        null,
        '',
      ]);
    });

    test('returns null when nothing is usable', () {
      expect(parseCealingRules('{"a":1}'), isNull);
      expect(parseCealingRules('[]'), isNull);
      expect(parseCealingRules('not json'), isNull);
      expect(parseCealingRules(''), isNull);
    });
  });

  group('mergeCealingRules', () {
    test('replaces a rule with the same domain set and keeps order', () {
      final existing = [
        [
          ['*a.test'],
          'old.test',
          '1.1.1.1',
        ],
      ];
      final incoming = [
        [
          ['*a.test'],
          'new.test',
          '2.2.2.2',
        ],
        [
          ['*b.test'],
          'other.test',
          '3.3.3.3',
        ],
      ];
      final merged = mergeCealingRules(existing, incoming);
      expect(merged, hasLength(2));
      expect((merged.first as List)[1], 'new.test');
      expect((merged.last as List)[0], ['*b.test']);
    });

    test('keeps rules whose domain set differs', () {
      final merged = mergeCealingRules(
        [
          [
            ['*a.test'],
            'x.test',
            '1.1.1.1',
          ],
        ],
        [
          [
            ['*a.test', '*b.test'],
            'y.test',
            '2.2.2.2',
          ],
        ],
      );
      expect(merged, hasLength(2));
    });
  });

  test('encodeCealingRules round-trips through parseCealingRules', () {
    final rules = parseCealingRules(
      '[[["*a.test"],"g.cn","1.1.1.1"],[["*b.test"],null,""]]',
    );
    expect(parseCealingRules(encodeCealingRules(rules!)), rules);
  });
}
