/// Pure-Dart, conservative document classification and labeled date extraction.
///
/// This module only proposes metadata. It never verifies a date and it never
/// infers a deadline from an issue or purchase date alone.
library;

import 'package:lifevault/core/contracts/contracts.dart';

/// Stateless keyword-based implementation of [DocumentExtractionService].
///
/// The service deliberately favours a safe `other` result over a weak guess.
/// Every non-default suggestion carries the keyword evidence that produced it.
class LifeVaultDocumentExtractionService implements DocumentExtractionService {
  const LifeVaultDocumentExtractionService();

  static const Map<DocumentCategory, List<_Signal>> _categorySignals =
      <DocumentCategory, List<_Signal>>{
    DocumentCategory.medical: <_Signal>[
      _Signal('prescription', 4),
      _Signal('hospital', 3),
      _Signal('clinic', 3),
      _Signal('medical record', 4),
      _Signal('laboratory', 3),
      _Signal('diagnostic', 3),
      _Signal('pathology', 3),
      _Signal('doctor', 2),
    ],
    DocumentCategory.finance: <_Signal>[
      _Signal('bank statement', 4),
      _Signal('credit card', 4),
      _Signal('account number', 2),
      _Signal('income tax', 4),
      _Signal('loan account', 4),
      _Signal('financial statement', 4),
      _Signal('interest rate', 2),
    ],
    DocumentCategory.appliances: <_Signal>[
      _Signal('refrigerator', 4),
      _Signal('fridge', 4),
      _Signal('washing machine', 4),
      _Signal('air conditioner', 4),
      _Signal('microwave', 4),
      _Signal('appliance', 3),
      _Signal('television', 3),
      _Signal('water purifier', 4),
    ],
    DocumentCategory.vehicles: <_Signal>[
      _Signal('vehicle registration', 5),
      _Signal('registration certificate', 4),
      _Signal('motorcycle', 3),
      _Signal('scooter', 3),
      _Signal('vehicle', 2),
      _Signal('car', 2),
      _Signal('bike', 2),
      _Signal('puc', 4),
    ],
    DocumentCategory.insurance: <_Signal>[
      _Signal('insurance policy', 5),
      _Signal('insurance', 4),
      _Signal('policy number', 3),
      _Signal('policy period', 4),
      _Signal('premium', 3),
      _Signal('insurer', 4),
      _Signal('sum insured', 4),
    ],
    DocumentCategory.homeUtilities: <_Signal>[
      _Signal('electricity bill', 5),
      _Signal('water bill', 5),
      _Signal('broadband', 4),
      _Signal('utility bill', 5),
      _Signal('gas bill', 5),
      _Signal('rent receipt', 4),
      _Signal('landlord', 3),
      _Signal('meter number', 3),
    ],
    DocumentCategory.identityPersonal: <_Signal>[
      _Signal('passport', 4),
      _Signal('aadhaar', 4),
      _Signal('pan card', 4),
      _Signal('voter id', 4),
      _Signal('identity card', 4),
      _Signal('birth certificate', 4),
      _Signal('driving licence', 4),
    ],
    DocumentCategory.education: <_Signal>[
      _Signal('university', 4),
      _Signal('college', 3),
      _Signal('school', 3),
      _Signal('student id', 4),
      _Signal('enrollment', 4),
      _Signal('tuition fee', 4),
      _Signal('semester', 3),
      _Signal('marksheet', 4),
    ],
    DocumentCategory.legalLetters: <_Signal>[
      _Signal('legal notice', 5),
      _Signal('agreement', 4),
      _Signal('affidavit', 4),
      _Signal('court', 3),
      _Signal('advocate', 3),
      _Signal('contract', 4),
      _Signal('official letter', 3),
    ],
  };

  static const Map<DocumentType, List<_Signal>> _typeSignals =
      <DocumentType, List<_Signal>>{
    DocumentType.insurancePolicy: <_Signal>[
      _Signal('insurance policy', 6),
      _Signal('policy period', 5),
      _Signal('insurance', 4),
      _Signal('policy number', 3),
    ],
    DocumentType.warranty: <_Signal>[
      _Signal('warranty', 6),
      _Signal('guarantee', 4),
      _Signal('extended protection', 4),
    ],
    DocumentType.bill: <_Signal>[
      _Signal('payment due', 6),
      _Signal('due date', 5),
      _Signal('amount due', 5),
      _Signal('pay before', 5),
      _Signal('bill', 3),
    ],
    DocumentType.invoiceReceipt: <_Signal>[
      _Signal('tax invoice', 6),
      _Signal('invoice', 5),
      _Signal('receipt', 4),
      _Signal('cash memo', 4),
    ],
    DocumentType.medicalRecord: <_Signal>[
      _Signal('medical record', 6),
      _Signal('lab report', 5),
      _Signal('diagnostic report', 5),
      _Signal('discharge summary', 5),
    ],
    DocumentType.prescription: <_Signal>[
      _Signal('prescription', 6),
      _Signal('rx', 3),
      _Signal('dosage', 4),
    ],
    DocumentType.registration: <_Signal>[
      _Signal('registration certificate', 6),
      _Signal('vehicle registration', 6),
      _Signal('registration no', 4),
    ],
    DocumentType.certificate: <_Signal>[
      _Signal('certificate', 5),
      _Signal('certified that', 4),
    ],
    DocumentType.letter: <_Signal>[
      _Signal('legal notice', 5),
      _Signal('dear ', 3),
      _Signal('official letter', 5),
      _Signal('to whom it may concern', 5),
      _Signal('sincerely', 3),
    ],
  };

  static final RegExp _dateToken = RegExp(
    r'\b(?:\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{2,4})\b',
    caseSensitive: false,
  );

  static final List<_DateLabel> _dateLabels = <_DateLabel>[
    _DateLabel(
      RegExp(
        r'\b(?:expiry\s*date|expiration\s*date|expires?\s*(?:on|date)?|valid\s*(?:until|upto|till)|policy\s*period\s*(?:to|until)|policy\s*end)\b',
        caseSensitive: false,
      ),
      DateFieldKind.expiry,
      ConfidenceLevel.high,
    ),
    _DateLabel(
      RegExp(
        r'\b(?:warranty\s*(?:ends?|end\s*date|valid\s*(?:until|upto|till))|warranty\s*expiry)\b',
        caseSensitive: false,
      ),
      DateFieldKind.expiry,
      ConfidenceLevel.high,
    ),
    _DateLabel(
      RegExp(
        r'\b(?:payment\s*due|due\s*date|bill\s*due|pay\s*before|amount\s*due|due\s*on)\b',
        caseSensitive: false,
      ),
      DateFieldKind.due,
      ConfidenceLevel.high,
    ),
  ];

  @override
  ExtractionResult extract(String ocrText) {
    final normalized = _normalize(ocrText);
    if (normalized.trim().isEmpty) {
      return const ExtractionResult(
        categoryEvidence: 'Low confidence: no readable text.',
        typeEvidence: 'Low confidence: no readable text.',
      );
    }

    final category = _bestSuggestion<DocumentCategory>(
      normalized,
      _categorySignals,
      DocumentCategory.other,
    );
    final type = _bestSuggestion<DocumentType>(
      normalized,
      _typeSignals,
      DocumentType.other,
    );
    final candidates = <DateCandidate>[
      ..._extractLabeledDates(normalized),
      ..._deriveWarrantyEnd(normalized),
    ];

    return ExtractionResult(
      suggestedCategory: category.value,
      suggestedType: type.value,
      categoryEvidence: category.evidence,
      typeEvidence: type.evidence,
      dateCandidates: candidates,
      assetNameSuggestion: _assetSuggestion(normalized),
    );
  }

  _Suggestion<T> _bestSuggestion<T>(
    String text,
    Map<T, List<_Signal>> signalSets,
    T fallback,
  ) {
    T selected = fallback;
    var selectedScore = 0;
    final selectedSignals = <String>[];

    for (final entry in signalSets.entries) {
      var score = 0;
      final matches = <String>[];
      for (final signal in entry.value) {
        if (_containsPhrase(text, signal.phrase)) {
          score += signal.weight;
          matches.add(signal.phrase);
        }
      }
      if (score > selectedScore) {
        selected = entry.key;
        selectedScore = score;
        selectedSignals
          ..clear()
          ..addAll(matches);
      }
    }

    if (selectedScore == 0) {
      return _Suggestion<T>(
        fallback,
        'Low confidence: no known category/type keyword; defaulted to other.',
      );
    }
    return _Suggestion<T>(
      selected,
      'Keyword evidence: ${selectedSignals.join(', ')} (score $selectedScore).',
    );
  }

  List<DateCandidate> _extractLabeledDates(String text) {
    final lines = text.split('\n');
    final candidates = <DateCandidate>[];

    for (var index = 0; index < lines.length; index++) {
      final labelLine = lines[index];
      final snippet = _snippetFor(lines, index);
      for (final label in _dateLabels) {
        final labelMatch = label.pattern.firstMatch(labelLine);
        if (labelMatch == null) {
          continue;
        }
        final match = _dateToken.firstMatch(snippet.substring(labelMatch.end));
        if (match == null) {
          continue;
        }
        final rawDate = match.group(0)!;
        final parsed = _parseDate(rawDate);
        if (parsed == null && !_looksAmbiguousOrTwoDigitYear(rawDate)) {
          continue;
        }
        candidates.add(
          DateCandidate(
            fieldKind: label.fieldKind,
            rawText: rawDate,
            isoDate: parsed?.toIso8601String().substring(0, 10),
            sourceSnippet: snippet,
            ambiguous: parsed == null,
            confidenceLevel:
                parsed == null ? ConfidenceLevel.low : label.confidenceLevel,
          ),
        );
      }
    }
    return candidates;
  }

  List<DateCandidate> _deriveWarrantyEnd(String text) {
    final hasWarranty =
        RegExp(r'\bwarranty\b', caseSensitive: false).hasMatch(text);
    if (!hasWarranty) {
      return const <DateCandidate>[];
    }

    final durationMatch = RegExp(
      r'\b(?:warranty\s*(?:period|duration)?\s*[:\-]?\s*)?(\d{1,2})\s*(months?|years?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final purchaseMatch = RegExp(
      r'\b(?:purchase\s*date|date\s*of\s*purchase)\s*[:\-]?\s*([^\n]{1,48})',
      caseSensitive: false,
    ).firstMatch(text);
    if (durationMatch == null || purchaseMatch == null) {
      return const <DateCandidate>[];
    }

    final duration = int.tryParse(durationMatch.group(1)!);
    final unit = durationMatch.group(2)!.toLowerCase();
    final purchaseDateMatch = _dateToken.firstMatch(purchaseMatch.group(1)!);
    if (duration == null || duration == 0 || purchaseDateMatch == null) {
      return const <DateCandidate>[];
    }
    final purchase = _parseDate(purchaseDateMatch.group(0)!);
    if (purchase == null) {
      return const <DateCandidate>[];
    }

    final months = unit.startsWith('year') ? duration * 12 : duration;
    final derived = _addMonthsClamped(purchase, months);
    final snippet = _compactSnippet(
      '${purchaseMatch.group(0)!}; ${durationMatch.group(0)!}',
    );
    return <DateCandidate>[
      DateCandidate(
        fieldKind: DateFieldKind.expiry,
        rawText: '${purchaseDateMatch.group(0)!} + ${durationMatch.group(0)!}',
        isoDate: derived.toIso8601String().substring(0, 10),
        sourceSnippet: snippet,
        isDerived: true,
        confidenceLevel: ConfidenceLevel.medium,
      ),
    ];
  }

  DateTime? _parseDate(String raw) {
    final compact = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(compact);
    if (iso != null) {
      return _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final named = RegExp(
      r'^(\d{1,2})\s+([a-z]+)\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(compact);
    if (named != null) {
      final month = _monthNumber(named.group(2)!);
      return month == null
          ? null
          : _validDate(
              int.parse(named.group(3)!),
              month,
              int.parse(named.group(1)!),
            );
    }

    final numeric =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(compact);
    if (numeric == null) {
      return null;
    }
    final day = int.parse(numeric.group(1)!);
    final month = int.parse(numeric.group(2)!);
    if (day <= 12 && month <= 12) {
      return null;
    }
    return _validDate(int.parse(numeric.group(3)!), month, day);
  }

  bool _looksAmbiguousOrTwoDigitYear(String raw) {
    final numeric =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(raw);
    if (numeric != null) {
      if (numeric.group(3)!.length == 2) {
        return true;
      }
      return int.parse(numeric.group(1)!) <= 12 &&
          int.parse(numeric.group(2)!) <= 12;
    }
    return RegExp(r'^\d{1,2}\s+[a-zA-Z]+\s+\d{2}$').hasMatch(raw);
  }

  DateTime? _validDate(int year, int month, int day) {
    if (year < 1900 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final value = DateTime.utc(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  DateTime _addMonthsClamped(DateTime source, int months) {
    final zeroBasedMonth = source.month - 1 + months;
    final targetYear = source.year + zeroBasedMonth ~/ 12;
    final targetMonth = zeroBasedMonth % 12 + 1;
    final lastDay = DateTime.utc(targetYear, targetMonth + 1, 0).day;
    final targetDay = source.day > lastDay ? lastDay : source.day;
    return DateTime.utc(targetYear, targetMonth, targetDay);
  }

  int? _monthNumber(String name) {
    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[name.toLowerCase()];
  }

  String? _assetSuggestion(String text) {
    const assetSignals = <String, String>{
      'motorcycle': 'Motorcycle',
      'scooter': 'Scooter',
      'bike': 'Bike',
      'car': 'Car',
      'refrigerator': 'Refrigerator',
      'fridge': 'Fridge',
      'washing machine': 'Washing Machine',
      'air conditioner': 'Air Conditioner',
      'microwave': 'Microwave',
    };
    for (final entry in assetSignals.entries) {
      if (_containsPhrase(text, entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String _snippetFor(List<String> lines, int index) {
    final following = index + 1 < lines.length ? lines[index + 1] : '';
    return _compactSnippet('${lines[index]} $following');
  }

  String _compactSnippet(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 180 ? compact : '${compact.substring(0, 177)}...';
  }

  String _normalize(String value) =>
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  static bool _containsPhrase(String text, String phrase) {
    final escaped = RegExp.escape(phrase).replaceAll(' ', r'\s+');
    return RegExp('(?<![a-z0-9])$escaped(?![a-z0-9])', caseSensitive: false)
        .hasMatch(text);
  }
}

/// Backwards-friendly explicit name for the keyword implementation.
class KeywordDocumentExtractionService
    extends LifeVaultDocumentExtractionService {
  const KeywordDocumentExtractionService();
}

class _Signal {
  const _Signal(this.phrase, this.weight);

  final String phrase;
  final int weight;
}

class _DateLabel {
  const _DateLabel(this.pattern, this.fieldKind, this.confidenceLevel);

  final RegExp pattern;
  final DateFieldKind fieldKind;
  final ConfidenceLevel confidenceLevel;
}

class _Suggestion<T> {
  const _Suggestion(this.value, this.evidence);

  final T value;
  final String evidence;
}
