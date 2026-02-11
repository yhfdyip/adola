class ReaderReplaceRuleState {
  const ReaderReplaceRuleState({
    required this.name,
    required this.pattern,
    required this.replacement,
    this.enabled = true,
    this.isRegex = false,
  });

  final String name;
  final String pattern;
  final String replacement;
  final bool enabled;
  final bool isRegex;

  ReaderReplaceRuleState copyWith({
    String? name,
    String? pattern,
    String? replacement,
    bool? enabled,
    bool? isRegex,
  }) {
    return ReaderReplaceRuleState(
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      enabled: enabled ?? this.enabled,
      isRegex: isRegex ?? this.isRegex,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'enabled': enabled,
      'isRegex': isRegex,
    };
  }

  static ReaderReplaceRuleState fromJson(Map<String, Object?> json) {
    return ReaderReplaceRuleState(
      name: (json['name'] as String? ?? '').trim(),
      pattern: (json['pattern'] as String? ?? '').trim(),
      replacement: json['replacement'] as String? ?? '',
      enabled: _parseBool(json['enabled'], true),
      isRegex: _parseBool(json['isRegex'], false),
    );
  }
}

class ReaderViewConfigState {
  const ReaderViewConfigState({
    this.tone = 'follow',
    this.pageAnim = 'cover',
    this.imageStyle = 'normal',
    this.progressBehavior = 'page',
    this.fontSize = 18,
    this.lineHeight = 1.75,
    this.letterSpacing = 0,
    this.boldText = false,
    this.expandTextMenu = false,
    this.replaceRuleEnabled = true,
    this.reSegmentEnabled = false,
    this.sameTitleRemoved = false,
    this.reverseContent = false,
    this.simulatedReading = false,
    this.showReadTitleAddition = true,
    this.followSystemTts = true,
    this.readAloudSpeed = 1,
    this.readAloudTimerMinutes = 0,
  });

  static const ReaderViewConfigState defaults = ReaderViewConfigState();

  final String tone;
  final String pageAnim;
  final String imageStyle;
  final String progressBehavior;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final bool boldText;
  final bool expandTextMenu;
  final bool replaceRuleEnabled;
  final bool reSegmentEnabled;
  final bool sameTitleRemoved;
  final bool reverseContent;
  final bool simulatedReading;
  final bool showReadTitleAddition;
  final bool followSystemTts;
  final double readAloudSpeed;
  final int readAloudTimerMinutes;

  bool get isDefault {
    return sameAs(defaults);
  }

  bool sameAs(ReaderViewConfigState other) {
    return tone == other.tone &&
        pageAnim == other.pageAnim &&
        imageStyle == other.imageStyle &&
        progressBehavior == other.progressBehavior &&
        fontSize == other.fontSize &&
        lineHeight == other.lineHeight &&
        letterSpacing == other.letterSpacing &&
        boldText == other.boldText &&
        expandTextMenu == other.expandTextMenu &&
        replaceRuleEnabled == other.replaceRuleEnabled &&
        reSegmentEnabled == other.reSegmentEnabled &&
        sameTitleRemoved == other.sameTitleRemoved &&
        reverseContent == other.reverseContent &&
        simulatedReading == other.simulatedReading &&
        showReadTitleAddition == other.showReadTitleAddition &&
        followSystemTts == other.followSystemTts &&
        readAloudSpeed == other.readAloudSpeed &&
        readAloudTimerMinutes == other.readAloudTimerMinutes;
  }

  ReaderViewConfigState copyWith({
    String? tone,
    String? pageAnim,
    String? imageStyle,
    String? progressBehavior,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    bool? boldText,
    bool? expandTextMenu,
    bool? replaceRuleEnabled,
    bool? reSegmentEnabled,
    bool? sameTitleRemoved,
    bool? reverseContent,
    bool? simulatedReading,
    bool? showReadTitleAddition,
    bool? followSystemTts,
    double? readAloudSpeed,
    int? readAloudTimerMinutes,
  }) {
    return ReaderViewConfigState(
      tone: tone ?? this.tone,
      pageAnim: pageAnim ?? this.pageAnim,
      imageStyle: imageStyle ?? this.imageStyle,
      progressBehavior: progressBehavior ?? this.progressBehavior,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      boldText: boldText ?? this.boldText,
      expandTextMenu: expandTextMenu ?? this.expandTextMenu,
      replaceRuleEnabled: replaceRuleEnabled ?? this.replaceRuleEnabled,
      reSegmentEnabled: reSegmentEnabled ?? this.reSegmentEnabled,
      sameTitleRemoved: sameTitleRemoved ?? this.sameTitleRemoved,
      reverseContent: reverseContent ?? this.reverseContent,
      simulatedReading: simulatedReading ?? this.simulatedReading,
      showReadTitleAddition: showReadTitleAddition ?? this.showReadTitleAddition,
      followSystemTts: followSystemTts ?? this.followSystemTts,
      readAloudSpeed: readAloudSpeed ?? this.readAloudSpeed,
      readAloudTimerMinutes: readAloudTimerMinutes ?? this.readAloudTimerMinutes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'tone': tone,
      'pageAnim': pageAnim,
      'imageStyle': imageStyle,
      'progressBehavior': progressBehavior,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'boldText': boldText,
      'expandTextMenu': expandTextMenu,
      'replaceRuleEnabled': replaceRuleEnabled,
      'reSegmentEnabled': reSegmentEnabled,
      'sameTitleRemoved': sameTitleRemoved,
      'reverseContent': reverseContent,
      'simulatedReading': simulatedReading,
      'showReadTitleAddition': showReadTitleAddition,
      'followSystemTts': followSystemTts,
      'readAloudSpeed': readAloudSpeed,
      'readAloudTimerMinutes': readAloudTimerMinutes,
    };
  }

  static ReaderViewConfigState fromJson(Map<String, Object?> json) {
    return ReaderViewConfigState(
      tone: _parseString(json['tone'], defaults.tone),
      pageAnim: _parseString(json['pageAnim'], defaults.pageAnim),
      imageStyle: _parseString(json['imageStyle'], defaults.imageStyle),
      progressBehavior: _parseString(
        json['progressBehavior'],
        defaults.progressBehavior,
      ),
      fontSize: _parseDouble(json['fontSize'], defaults.fontSize),
      lineHeight: _parseDouble(json['lineHeight'], defaults.lineHeight),
      letterSpacing: _parseDouble(json['letterSpacing'], defaults.letterSpacing),
      boldText: _parseBool(json['boldText'], defaults.boldText),
      expandTextMenu: _parseBool(json['expandTextMenu'], defaults.expandTextMenu),
      replaceRuleEnabled: _parseBool(
        json['replaceRuleEnabled'],
        defaults.replaceRuleEnabled,
      ),
      reSegmentEnabled: _parseBool(
        json['reSegmentEnabled'],
        defaults.reSegmentEnabled,
      ),
      sameTitleRemoved: _parseBool(
        json['sameTitleRemoved'],
        defaults.sameTitleRemoved,
      ),
      reverseContent: _parseBool(json['reverseContent'], defaults.reverseContent),
      simulatedReading: _parseBool(
        json['simulatedReading'],
        defaults.simulatedReading,
      ),
      showReadTitleAddition: _parseBool(
        json['showReadTitleAddition'],
        defaults.showReadTitleAddition,
      ),
      followSystemTts: _parseBool(
        json['followSystemTts'],
        defaults.followSystemTts,
      ),
      readAloudSpeed: _parseDouble(json['readAloudSpeed'], defaults.readAloudSpeed),
      readAloudTimerMinutes: _parseInt(
        json['readAloudTimerMinutes'],
        defaults.readAloudTimerMinutes,
      ),
    );
  }
}

class ReaderBookDraftState {
  const ReaderBookDraftState({
    this.chapterContentOverrides = const {},
    this.chapterTitleOverrides = const {},
    this.replaceRules = const [],
    this.config,
  });

  final Map<int, List<String>> chapterContentOverrides;
  final Map<int, String> chapterTitleOverrides;
  final List<ReaderReplaceRuleState> replaceRules;
  final ReaderViewConfigState? config;

  bool get isEmpty {
    return chapterContentOverrides.isEmpty &&
        chapterTitleOverrides.isEmpty &&
        replaceRules.isEmpty &&
        (config == null || config!.isDefault);
  }

  ReaderBookDraftState copyWith({
    Map<int, List<String>>? chapterContentOverrides,
    Map<int, String>? chapterTitleOverrides,
    List<ReaderReplaceRuleState>? replaceRules,
    ReaderViewConfigState? config,
  }) {
    return ReaderBookDraftState(
      chapterContentOverrides:
          chapterContentOverrides ?? this.chapterContentOverrides,
      chapterTitleOverrides: chapterTitleOverrides ?? this.chapterTitleOverrides,
      replaceRules: replaceRules ?? this.replaceRules,
      config: config ?? this.config,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'chapterContentOverrides': chapterContentOverrides.map(
        (chapterIndex, lines) =>
            MapEntry(chapterIndex.toString(), List<String>.from(lines)),
      ),
      'chapterTitleOverrides': chapterTitleOverrides.map(
        (chapterIndex, chapterTitle) =>
            MapEntry(chapterIndex.toString(), chapterTitle),
      ),
      'replaceRules': replaceRules
          .map((rule) => rule.toJson())
          .toList(growable: false),
      'config': config == null || config!.isDefault ? null : config!.toJson(),
    };
  }

  static ReaderBookDraftState fromJson(Map<String, Object?> json) {
    final chapterContentOverrides = <int, List<String>>{};
    final chapterContentRaw = json['chapterContentOverrides'];
    if (chapterContentRaw is Map) {
      for (final entry in chapterContentRaw.entries) {
        final chapterIndex = int.tryParse(entry.key.toString());
        if (chapterIndex == null || entry.value is! List) {
          continue;
        }

        final lines = (entry.value as List)
            .map((line) => line.toString().trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false);
        if (lines.isEmpty) {
          continue;
        }
        chapterContentOverrides[chapterIndex] = lines;
      }
    }

    final chapterTitleOverrides = <int, String>{};
    final chapterTitleRaw = json['chapterTitleOverrides'];
    if (chapterTitleRaw is Map) {
      for (final entry in chapterTitleRaw.entries) {
        final chapterIndex = int.tryParse(entry.key.toString());
        if (chapterIndex == null) {
          continue;
        }

        final chapterTitle = entry.value.toString().trim();
        if (chapterTitle.isEmpty) {
          continue;
        }
        chapterTitleOverrides[chapterIndex] = chapterTitle;
      }
    }

    final replaceRules = <ReaderReplaceRuleState>[];
    final replaceRulesRaw = json['replaceRules'];
    if (replaceRulesRaw is List) {
      for (final item in replaceRulesRaw) {
        if (item is! Map) {
          continue;
        }

        final rule = ReaderReplaceRuleState.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (rule.pattern.isEmpty) {
          continue;
        }
        replaceRules.add(rule);
      }
    }

    ReaderViewConfigState? config;
    final configRaw = json['config'];
    if (configRaw is Map) {
      config = ReaderViewConfigState.fromJson(
        configRaw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return ReaderBookDraftState(
      chapterContentOverrides: chapterContentOverrides,
      chapterTitleOverrides: chapterTitleOverrides,
      replaceRules: replaceRules,
      config: config,
    );
  }
}

bool _parseBool(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
  }
  return fallback;
}

String _parseString(Object? value, String fallback) {
  if (value is! String) {
    return fallback;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? fallback : normalized;
}

double _parseDouble(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

int _parseInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}
