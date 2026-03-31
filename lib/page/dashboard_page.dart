import 'package:flutter/material.dart';

import 'package:bahibo/component/app_back_button.dart';
import 'package:bahibo/theme/app_theme_extensions.dart';

class StudioDashboardPage extends StatefulWidget {
  final String studioName;
  final List<Map<String, dynamic>> products;

  const StudioDashboardPage({
    super.key,
    required this.studioName,
    required this.products,
  });

  @override
  State<StudioDashboardPage> createState() => _StudioDashboardPageState();
}

class _StudioDashboardPageState extends State<StudioDashboardPage> {
  static const String _allCurvesLabel = 'Tout';

  _DashboardRange _selectedRange = _DashboardRange.lastWeek;
  _DashboardPointSelection? _selectedMainPoint;
  _DashboardPointSelection? _selectedFollowerPoint;
  String _activeMainCurveLabel = _allCurvesLabel;

  String get _displayStudioName {
    final sanitized = widget.studioName
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();
    return sanitized.isEmpty ? 'Boutique' : sanitized;
  }

  static const Map<_DashboardRange, _DashboardSnapshot> _snapshots = {
    _DashboardRange.last5Days: _DashboardSnapshot(
      sales: '1.8M MGA',
      orders: '42',
      visits: '1.9k',
      likes: '640',
      growth: '+12%',
      bars: [0.38, 0.46, 0.62, 0.58, 0.84],
      labels: ['J-4', 'J-3', 'J-2', 'J-1', 'Auj'],
      followersCurve: [0.18, 0.24, 0.29, 0.33, 0.46],
      likesCurve: [0.36, 0.44, 0.57, 0.63, 0.80],
      viewsCurve: [0.42, 0.51, 0.60, 0.56, 0.72],
      productAddsCurve: [0.22, 0.28, 0.31, 0.35, 0.48],
    ),
    _DashboardRange.lastWeek: _DashboardSnapshot(
      sales: '3.4M MGA',
      orders: '89',
      visits: '3.8k',
      likes: '1.2k',
      growth: '+18%',
      bars: [0.35, 0.58, 0.47, 0.74, 0.62, 0.85, 0.68],
      labels: ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
      followersCurve: [0.14, 0.19, 0.27, 0.33, 0.39, 0.51, 0.48],
      likesCurve: [0.24, 0.42, 0.38, 0.58, 0.51, 0.80, 0.66],
      viewsCurve: [0.31, 0.48, 0.52, 0.63, 0.60, 0.72, 0.70],
      productAddsCurve: [0.18, 0.23, 0.21, 0.32, 0.36, 0.43, 0.39],
    ),
    _DashboardRange.lastMonth: _DashboardSnapshot(
      sales: '12.6M MGA',
      orders: '312',
      visits: '14.8k',
      likes: '4.6k',
      growth: '+24%',
      bars: [0.28, 0.36, 0.42, 0.48, 0.56, 0.62, 0.74, 0.68],
      labels: ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'],
      followersCurve: [0.10, 0.16, 0.21, 0.28, 0.35, 0.41, 0.50, 0.56],
      likesCurve: [0.20, 0.28, 0.36, 0.45, 0.55, 0.61, 0.74, 0.69],
      viewsCurve: [0.26, 0.34, 0.40, 0.47, 0.59, 0.67, 0.71, 0.76],
      productAddsCurve: [0.12, 0.18, 0.22, 0.26, 0.33, 0.37, 0.43, 0.40],
    ),
    _DashboardRange.last3Months: _DashboardSnapshot(
      sales: '36.9M MGA',
      orders: '901',
      visits: '39.5k',
      likes: '12.4k',
      growth: '+31%',
      bars: [0.32, 0.45, 0.52, 0.61, 0.72, 0.82],
      labels: ['M-5', 'M-4', 'M-3', 'M-2', 'M-1', 'Act'],
      followersCurve: [0.12, 0.18, 0.24, 0.31, 0.42, 0.54],
      likesCurve: [0.28, 0.34, 0.46, 0.58, 0.69, 0.82],
      viewsCurve: [0.33, 0.40, 0.49, 0.62, 0.72, 0.78],
      productAddsCurve: [0.14, 0.19, 0.25, 0.34, 0.41, 0.52],
    ),
    _DashboardRange.lastYear: _DashboardSnapshot(
      sales: '118.4M MGA',
      orders: '2.8k',
      visits: '128k',
      likes: '39k',
      growth: '+44%',
      bars: [0.24, 0.30, 0.44, 0.48, 0.58, 0.64, 0.69, 0.76, 0.83, 0.88],
      labels: ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O'],
      followersCurve: [0.08, 0.11, 0.16, 0.21, 0.27, 0.34, 0.41, 0.49, 0.56, 0.63],
      likesCurve: [0.16, 0.22, 0.30, 0.38, 0.44, 0.55, 0.63, 0.71, 0.78, 0.86],
      viewsCurve: [0.20, 0.26, 0.34, 0.41, 0.49, 0.58, 0.64, 0.72, 0.80, 0.90],
      productAddsCurve: [0.10, 0.14, 0.18, 0.24, 0.31, 0.38, 0.43, 0.50, 0.58, 0.66],
    ),
  };

  _DashboardSnapshot get _snapshot => _snapshots[_selectedRange]!;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;
    final support = theme.colorScheme.tertiary;

    return Scaffold(
      backgroundColor: appColors.backgroundBase,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primary.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.12
                            : 0.08,
                      ),
                      appColors.backgroundBase,
                      appColors.backgroundBase,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
              children: [
                const SizedBox(height: 54),
                _buildHeroCard(theme),
                const SizedBox(height: 18),
                _buildRangeFilters(theme),
                const SizedBox(height: 18),
                _buildActivityCurvesCard(theme),
                const SizedBox(height: 18),
                _buildChartCard(theme, primary, support),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: const AppBackButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    final appColors = theme.appColors;
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withValues(alpha: 0.94), appColors.heroAccent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tableau de bord complet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: appColors.heroForeground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_displayStudioName · pilotage des performances sur la periode selectionnee.',
            style: TextStyle(
              color: appColors.heroForegroundMuted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: appColors.heroSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: appColors.heroBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: appColors.heroForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Croissance globale ${_snapshot.growth} sur ${_selectedRange.label.toLowerCase()}.',
                    style: TextStyle(
                      color: appColors.heroForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeFilters(ThemeData theme) {
    final primary = theme.colorScheme.primary;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _DashboardRange.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final range = _DashboardRange.values[index];
          final isSelected = range == _selectedRange;
          return ChoiceChip(
            label: Text(range.label),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedRange = range;
                _selectedMainPoint = null;
                _selectedFollowerPoint = null;
                _activeMainCurveLabel = _allCurvesLabel;
              });
            },
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : primary,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: primary,
            backgroundColor: theme.appColors.panelBackground,
            side: BorderSide(color: theme.appColors.inputBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, Color primary, Color support) {
    final chartBaseColor = theme.brightness == Brightness.dark
        ? support.withValues(alpha: 0.34)
        : primary.withValues(alpha: 0.24);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.appColors.panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.appColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolution des performances',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lecture rapide des resultats sur ${_selectedRange.label.toLowerCase()}.',
            style: TextStyle(color: theme.appColors.mutedText),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_snapshot.bars.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              height: 142 * _snapshot.bars[index],
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    primary.withValues(alpha: 0.92),
                                    chartBaseColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _snapshot.labels[index],
                          style: TextStyle(
                            color: theme.appColors.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCurvesCard(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final viewsColor = theme.colorScheme.tertiary;
    final productsColor = theme.colorScheme.secondary;
    final followersColor = theme.colorScheme.error;
    final mainChartLines = [
      _DashboardLineData(
        label: 'Likes',
        color: primary,
        values: _snapshot.likesCurve,
      ),
      _DashboardLineData(
        label: 'Vues',
        color: viewsColor,
        values: _snapshot.viewsCurve,
      ),
      _DashboardLineData(
        label: 'Ajouts produit',
        color: productsColor,
        values: _snapshot.productAddsCurve,
      ),
    ];
    final followerLine = _DashboardLineData(
      label: 'Abonnes',
      color: followersColor,
      values: _snapshot.followersCurve,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.appColors.panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.appColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Courbes d activite',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Suivi des abonnes, des likes, des vues et des ajouts de produit.',
            style: TextStyle(color: theme.appColors.mutedText),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildLegendChip(
                theme,
                _allCurvesLabel,
                Colors.white,
                isSelected: _activeMainCurveLabel == _allCurvesLabel,
                opacity: _activeMainCurveLabel == _allCurvesLabel ? 1 : 0.18,
                onTap: () {
                  setState(() {
                    _activeMainCurveLabel = _allCurvesLabel;
                  });
                },
              ),
              ...mainChartLines.map((line) {
                final isActive = _isMainCurveActive(line.label);
                return _buildLegendChip(
                  theme,
                  line.label,
                  line.color,
                  isSelected: _activeMainCurveLabel == line.label,
                  opacity: isActive ? 1 : 0.18,
                  onTap: () {
                    setState(() {
                      _activeMainCurveLabel = line.label;
                      if (_selectedMainPoint != null &&
                          _selectedMainPoint!.label != line.label) {
                        _selectedMainPoint = null;
                      }
                    });
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 18),
          _buildCurvePlot(
            theme,
            lines: mainChartLines,
            height: 210,
            selection: _selectedMainPoint,
            onPointSelected: (selection) {
              setState(() {
                _selectedMainPoint = selection;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_snapshot.labels.length, (index) {
              return Expanded(
                child: Text(
                  _snapshot.labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.appColors.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _buildLegendChip(
            theme,
            followerLine.label,
            followerLine.color,
            isSelected: true,
            opacity: 1,
          ),
          const SizedBox(height: 14),
          _buildCurvePlot(
            theme,
            lines: [followerLine],
            height: 150,
            selection: _selectedFollowerPoint,
            onPointSelected: (selection) {
              setState(() {
                _selectedFollowerPoint = selection;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_snapshot.labels.length, (index) {
              return Expanded(
                child: Text(
                  _snapshot.labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.appColors.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCurvePlot(
    ThemeData theme, {
    required List<_DashboardLineData> lines,
    required double height,
    required _DashboardPointSelection? selection,
    required ValueChanged<_DashboardPointSelection?> onPointSelected,
  }) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartSize = Size(constraints.maxWidth, height);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              onPointSelected(
                _findNearestPoint(
                  localPosition: details.localPosition,
                  size: chartSize,
                  lines: lines,
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DashboardMultiLinePainter(
                      lines: lines,
                      gridColor: theme.dividerColor.withValues(alpha: 0.14),
                      selectedPoint: selection,
                      activeLineLabel: lines.length == 1
                          ? lines.first.label
                          : _activeMainCurveLabel,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (selection != null)
                  Positioned(
                    left: _tooltipLeft(selection.position.dx, constraints.maxWidth),
                    top: _tooltipTop(selection.position.dy),
                    child: _buildCurveValueTooltip(theme, selection),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _tooltipLeft(double pointDx, double width) {
    const tooltipWidth = 112.0;
    final centered = pointDx - (tooltipWidth / 2);
    return centered.clamp(0.0, width - tooltipWidth);
  }

  double _tooltipTop(double pointDy) {
    const tooltipHeight = 52.0;
    final desiredTop = pointDy - tooltipHeight - 12;
    return desiredTop < 0 ? 0 : desiredTop;
  }

  Widget _buildCurveValueTooltip(
    ThemeData theme,
    _DashboardPointSelection selection,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.appColors.panelBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selection.color.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selection.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selection.color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selection.valueText,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DashboardPointSelection? _findNearestPoint({
    required Offset localPosition,
    required Size size,
    required List<_DashboardLineData> lines,
  }) {
    final chartRect = _DashboardChartGeometry.chartRectForSize(size);
    if (!chartRect.inflate(18).contains(localPosition)) {
      return null;
    }

    _DashboardPointSelection? bestMatch;
    var minDistance = double.infinity;

    for (final line in lines) {
      final points = _DashboardChartGeometry.pointsForLine(line.values, size);
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final distance = (point - localPosition).distance;
        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = _DashboardPointSelection(
            label: line.label,
            valueText: _formatCurveValue(line.label, line.values[index]),
            position: point,
            color: line.color,
          );
        }
      }
    }

    return minDistance <= 28 ? bestMatch : null;
  }

  String _formatCurveValue(String label, double normalizedValue) {
    final normalized = normalizedValue.clamp(0.0, 1.0);
    final baseValues = <String, Map<_DashboardRange, int>>{
      'Abonnes': {
        _DashboardRange.last5Days: 180,
        _DashboardRange.lastWeek: 520,
        _DashboardRange.lastMonth: 1800,
        _DashboardRange.last3Months: 4800,
        _DashboardRange.lastYear: 14000,
      },
      'Likes': {
        _DashboardRange.last5Days: 640,
        _DashboardRange.lastWeek: 1200,
        _DashboardRange.lastMonth: 4600,
        _DashboardRange.last3Months: 12400,
        _DashboardRange.lastYear: 39000,
      },
      'Vues': {
        _DashboardRange.last5Days: 1900,
        _DashboardRange.lastWeek: 3800,
        _DashboardRange.lastMonth: 14800,
        _DashboardRange.last3Months: 39500,
        _DashboardRange.lastYear: 128000,
      },
      'Ajouts produit': {
        _DashboardRange.last5Days: 14,
        _DashboardRange.lastWeek: 26,
        _DashboardRange.lastMonth: 94,
        _DashboardRange.last3Months: 210,
        _DashboardRange.lastYear: 860,
      },
    };

    final baseValue = baseValues[label]?[_selectedRange] ?? 0;
    final resolvedValue = (baseValue * normalized).round();
    if (label == 'Ajouts produit') {
      return '$resolvedValue';
    }
    return _formatCompactNumber(resolvedValue);
  }

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      final compact = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${compact}M';
    }
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(
        value % 1000 == 0 ? 0 : 1,
      );
      return '${compact}k';
    }
    return '$value';
  }

  bool _isMainCurveActive(String label) {
    return _activeMainCurveLabel == _allCurvesLabel ||
        _activeMainCurveLabel == label;
  }

  Widget _buildLegendChip(
    ThemeData theme,
    String label,
    Color color, {
    required bool isSelected,
    required double opacity,
    VoidCallback? onTap,
  }) {
    final effectiveColor = color.withValues(alpha: opacity);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: isSelected ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: effectiveColor.withValues(alpha: isSelected ? 0.32 : 0.18),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DashboardRange {
  last5Days('Ces 5 derniers jours'),
  lastWeek('Cette derniere semaine'),
  lastMonth('Ce dernier mois'),
  last3Months('Ces 3 derniers mois'),
  lastYear('Cette annee');

  final String label;

  const _DashboardRange(this.label);
}

class _DashboardSnapshot {
  final String sales;
  final String orders;
  final String visits;
  final String likes;
  final String growth;
  final List<double> bars;
  final List<String> labels;
  final List<double> followersCurve;
  final List<double> likesCurve;
  final List<double> viewsCurve;
  final List<double> productAddsCurve;

  const _DashboardSnapshot({
    required this.sales,
    required this.orders,
    required this.visits,
    required this.likes,
    required this.growth,
    required this.bars,
    required this.labels,
    required this.followersCurve,
    required this.likesCurve,
    required this.viewsCurve,
    required this.productAddsCurve,
  });
}

class _DashboardLineData {
  final String label;
  final Color color;
  final List<double> values;

  const _DashboardLineData({
    required this.label,
    required this.color,
    required this.values,
  });
}

class _DashboardPointSelection {
  final String label;
  final String valueText;
  final Offset position;
  final Color color;

  const _DashboardPointSelection({
    required this.label,
    required this.valueText,
    required this.position,
    required this.color,
  });
}

class _DashboardChartGeometry {
  static const padding = EdgeInsets.fromLTRB(8, 16, 8, 18);

  static Rect chartRectForSize(Size size) {
    return Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );
  }

  static List<Offset> pointsForLine(List<double> values, Size size) {
    if (values.length < 2) {
      return const [];
    }

    final chartRect = chartRectForSize(size);
    final stepX = chartRect.width / (values.length - 1);
    return List.generate(values.length, (index) {
      final normalized = values[index].clamp(0.0, 1.0);
      final dx = chartRect.left + stepX * index;
      final dy = chartRect.bottom - (chartRect.height * normalized);
      return Offset(dx, dy);
    });
  }
}

class _DashboardMultiLinePainter extends CustomPainter {
  final List<_DashboardLineData> lines;
  final Color gridColor;
  final _DashboardPointSelection? selectedPoint;
  final String? activeLineLabel;

  const _DashboardMultiLinePainter({
    required this.lines,
    required this.gridColor,
    this.selectedPoint,
    this.activeLineLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) {
      return;
    }

    final chartRect = _DashboardChartGeometry.chartRectForSize(size);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index < 4; index++) {
      final dy = chartRect.top + (chartRect.height / 3) * index;
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    for (final line in lines) {
      if (line.values.length < 2) {
        continue;
      }

      final isDimmed = activeLineLabel != null &&
          activeLineLabel != _StudioDashboardPageState._allCurvesLabel &&
          activeLineLabel != line.label;
      final effectiveColor = line.color.withValues(alpha: isDimmed ? 0.18 : 1);

      final points = _DashboardChartGeometry.pointsForLine(line.values, size);

      final fillPath = Path()..moveTo(points.first.dx, chartRect.bottom);
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        if (index == 0) {
          fillPath.lineTo(point.dx, point.dy);
        } else {
          final previous = points[index - 1];
          final controlX = (previous.dx + point.dx) / 2;
          fillPath.cubicTo(controlX, previous.dy, controlX, point.dy, point.dx, point.dy);
        }
      }
      fillPath.lineTo(points.last.dx, chartRect.bottom);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            effectiveColor.withValues(alpha: isDimmed ? 0.05 : 0.16),
            effectiveColor.withValues(alpha: isDimmed ? 0.01 : 0.02),
          ],
        ).createShader(chartRect);
      canvas.drawPath(fillPath, fillPaint);

      final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length; index++) {
        final previous = points[index - 1];
        final point = points[index];
        final controlX = (previous.dx + point.dx) / 2;
        strokePath.cubicTo(controlX, previous.dy, controlX, point.dy, point.dx, point.dy);
      }

      final strokePaint = Paint()
        ..color = effectiveColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(strokePath, strokePaint);

      final pointPaint = Paint()..color = effectiveColor;
      final pointStrokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final point in points) {
        canvas.drawCircle(point, 4.5, pointPaint);
        canvas.drawCircle(point, 4.5, pointStrokePaint);
      }

      if (selectedPoint != null && selectedPoint!.label == line.label) {
        final selectedStrokePaint = Paint()
          ..color = effectiveColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        final selectedFillPaint = Paint()..color = Colors.white;
        canvas.drawCircle(selectedPoint!.position, 8, selectedFillPaint);
        canvas.drawCircle(selectedPoint!.position, 8, selectedStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardMultiLinePainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.activeLineLabel != activeLineLabel;
  }
}

