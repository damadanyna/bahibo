import 'package:banay/theme/app_theme_extensions.dart';
import 'package:flutter/material.dart';

/// Seller activity analytics for the account panel's "Statistique" tab
/// (formerly the standalone "Tableau de bord complet" page).

const String _allCurvesLabel = 'Tout';

enum SellerActivityRange {
  last5Days('Ces 5 derniers jours'),
  lastWeek('Cette dernière semaine'),
  lastMonth('Ce dernier mois'),
  last3Months('Ces 3 derniers mois'),
  lastYear('Cette année');

  final String label;

  const SellerActivityRange(this.label);
}

/// Bucketed series derived from the seller's catalog and profile counters.
/// Product adds are the only exactly dated signal; likes, views and followers
/// are totals spread across buckets proportionally to catalog activity.
class SellerActivitySnapshot {
  final SellerActivityRange range;
  final List<String> labels;
  final List<double> followersCurve;
  final List<int> followersActual;
  final List<double> likesCurve;
  final List<int> likesActual;
  final List<double> viewsCurve;
  final List<int> viewsActual;
  final List<double> productAddsCurve;
  final List<int> productAddsActual;

  const SellerActivitySnapshot({
    required this.range,
    required this.labels,
    required this.followersCurve,
    required this.followersActual,
    required this.likesCurve,
    required this.likesActual,
    required this.viewsCurve,
    required this.viewsActual,
    required this.productAddsCurve,
    required this.productAddsActual,
  });

  factory SellerActivitySnapshot.build({
    required List<Map<String, dynamic>> products,
    required String followerCount,
    required String visitorCount,
    required String totalLikesCount,
    required SellerActivityRange range,
  }) {
    final followersTotal = _parseCompactCount(followerCount);
    final viewsTotal = _parseCompactCount(visitorCount);
    final likesTotal = _parseCompactCount(totalLikesCount);

    final labels = _labelsForRange(range);
    final productAddsActual = _buildBucketSeriesFromProducts(
      products,
      range,
      (_) => 1,
    );
    final rawLikesActual = _buildBucketSeriesFromProducts(
      products,
      range,
      _parseProductLikes,
    );
    final likesActual = rawLikesActual.any((value) => value > 0)
        ? _distributeTotalAcrossBuckets(likesTotal, rawLikesActual)
        : _distributeTotalAcrossBuckets(likesTotal, productAddsActual);
    final viewsActual = _distributeTotalAcrossBuckets(
      viewsTotal,
      productAddsActual,
    );
    final followersActual = _distributeTotalAcrossBuckets(
      followersTotal,
      productAddsActual,
    );
    return SellerActivitySnapshot(
      range: range,
      labels: labels,
      followersCurve: _normalizeSeries(followersActual),
      followersActual: followersActual,
      likesCurve: _normalizeSeries(likesActual),
      likesActual: likesActual,
      viewsCurve: _normalizeSeries(viewsActual),
      viewsActual: viewsActual,
      productAddsCurve: _normalizeSeries(productAddsActual),
      productAddsActual: productAddsActual,
    );
  }

  static int _parseCompactCount(String value) {
    final normalizedValue = value.trim().toLowerCase();
    if (normalizedValue.isEmpty) {
      return 0;
    }

    final multiplier = normalizedValue.endsWith('k')
        ? 1000
        : normalizedValue.endsWith('m')
        ? 1000000
        : 1;
    final numericPart = normalizedValue.replaceAll(RegExp(r'[^0-9\.]'), '');
    final parsedValue = double.tryParse(numericPart);
    if (parsedValue == null) {
      return 0;
    }

    return (parsedValue * multiplier).round();
  }

  static int _parseProductLikes(Map<String, dynamic> product) {
    final rawLikes = product['likesCount'];
    if (rawLikes is num) {
      return rawLikes.toInt();
    }

    return int.tryParse('${rawLikes ?? 0}') ?? 0;
  }

  static DateTime? _parseProductCreatedAt(Map<String, dynamic> product) {
    final rawCreatedAt = product['createdAt'];
    if (rawCreatedAt is! String || rawCreatedAt.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawCreatedAt)?.toLocal();
  }

  static int _bucketCountForRange(SellerActivityRange range) {
    return switch (range) {
      SellerActivityRange.last5Days => 5,
      SellerActivityRange.lastWeek => 7,
      SellerActivityRange.lastMonth => 8,
      SellerActivityRange.last3Months => 6,
      SellerActivityRange.lastYear => 10,
    };
  }

  static Duration _windowForRange(SellerActivityRange range) {
    return switch (range) {
      SellerActivityRange.last5Days => const Duration(days: 5),
      SellerActivityRange.lastWeek => const Duration(days: 7),
      SellerActivityRange.lastMonth => const Duration(days: 56),
      SellerActivityRange.last3Months => const Duration(days: 180),
      SellerActivityRange.lastYear => const Duration(days: 300),
    };
  }

  static List<String> _labelsForRange(SellerActivityRange range) {
    return switch (range) {
      SellerActivityRange.last5Days => const [
        'J-4',
        'J-3',
        'J-2',
        'J-1',
        'Auj',
      ],
      SellerActivityRange.lastWeek => const ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
      SellerActivityRange.lastMonth => const [
        'S1',
        'S2',
        'S3',
        'S4',
        'S5',
        'S6',
        'S7',
        'S8',
      ],
      SellerActivityRange.last3Months => const [
        'M-5',
        'M-4',
        'M-3',
        'M-2',
        'M-1',
        'Act',
      ],
      SellerActivityRange.lastYear => const [
        'M-9',
        'M-8',
        'M-7',
        'M-6',
        'M-5',
        'M-4',
        'M-3',
        'M-2',
        'M-1',
        'Act',
      ],
    };
  }

  static List<int> _buildBucketSeriesFromProducts(
    List<Map<String, dynamic>> products,
    SellerActivityRange range,
    int Function(Map<String, dynamic>) valueOf,
  ) {
    final bucketCount = _bucketCountForRange(range);
    final window = _windowForRange(range);
    final now = DateTime.now();
    final start = now.subtract(window);
    final bucketSizeInMs = window.inMilliseconds / bucketCount;
    final values = List<int>.filled(bucketCount, 0);

    for (final product in products) {
      final createdAt = _parseProductCreatedAt(product);
      if (createdAt == null ||
          createdAt.isBefore(start) ||
          createdAt.isAfter(now)) {
        continue;
      }

      final diffInMs = createdAt.difference(start).inMilliseconds;
      var bucketIndex = (diffInMs / bucketSizeInMs).floor();
      if (bucketIndex < 0) {
        bucketIndex = 0;
      }
      if (bucketIndex >= bucketCount) {
        bucketIndex = bucketCount - 1;
      }

      values[bucketIndex] += valueOf(product);
    }

    return values;
  }

  static List<int> _distributeTotalAcrossBuckets(int total, List<int> weights) {
    if (total <= 0 || weights.isEmpty) {
      return List<int>.filled(weights.length, 0);
    }

    final normalizedWeights = weights.any((weight) => weight > 0)
        ? weights.map((weight) => weight + 1).toList()
        : List<int>.generate(weights.length, (index) => index + 1);
    final totalWeight = normalizedWeights.fold<int>(
      0,
      (sum, weight) => sum + weight,
    );
    final rawShares = normalizedWeights
        .map((weight) => total * weight / totalWeight)
        .toList();
    final distributed = rawShares.map((value) => value.floor()).toList();
    var remaining =
        total - distributed.fold<int>(0, (sum, value) => sum + value);

    final fractions = List.generate(rawShares.length, (index) => index)
      ..sort((left, right) {
        final leftFraction = rawShares[left] - distributed[left];
        final rightFraction = rawShares[right] - distributed[right];
        return rightFraction.compareTo(leftFraction);
      });

    for (var index = 0; index < fractions.length && remaining > 0; index++) {
      distributed[fractions[index]] += 1;
      remaining -= 1;
    }

    return distributed;
  }

  static List<double> _normalizeSeries(List<int> values) {
    if (values.isEmpty) {
      return const [];
    }

    final maxValue = values.reduce(
      (left, right) => left > right ? left : right,
    );
    if (maxValue <= 0) {
      return List<double>.filled(values.length, 0);
    }

    return values.map((value) => value / maxValue).toList();
  }
}

/// Horizontal range chips ("Ces 5 derniers jours" ... "Cette annee").
class SellerActivityRangeFilters extends StatelessWidget {
  final SellerActivityRange selected;
  final ValueChanged<SellerActivityRange> onSelected;

  /// Unselected chip surface / outline. Pass the host surface colors so the
  /// chips read as part of the same panel as the curves card.
  final Color? backgroundColor;
  final Color? borderColor;

  const SellerActivityRangeFilters({
    super.key,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final chipBackground = backgroundColor ?? theme.appColors.panelBackground;
    final chipBorder = borderColor ?? theme.appColors.inputBorder;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SellerActivityRange.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final range = SellerActivityRange.values[index];
          final isSelected = range == selected;
          return ChoiceChip(
            label: Text(range.label),
            selected: isSelected,
            onSelected: (_) => onSelected(range),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : primary,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: primary,
            backgroundColor: chipBackground,
            side: BorderSide(color: chipBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

/// "Courbes d activite" card: likes / views / product adds on one plot, with a
/// legend to isolate a curve, plus a separate followers plot. Tapping a point
/// shows its value. Selection state lives here so the host only rebuilds on
/// range changes.
class SellerActivityCurvesCard extends StatefulWidget {
  final SellerActivitySnapshot snapshot;

  /// When provided, the period chips are rendered inside the card (under the
  /// subtitle) and report the new period here; the host rebuilds the snapshot.
  final ValueChanged<SellerActivityRange>? onRangeSelected;

  /// Host surface style; defaults to a plain panel look.
  final BoxDecoration? decoration;

  const SellerActivityCurvesCard({
    super.key,
    required this.snapshot,
    this.onRangeSelected,
    this.decoration,
  });

  @override
  State<SellerActivityCurvesCard> createState() =>
      _SellerActivityCurvesCardState();
}

class _SellerActivityCurvesCardState extends State<SellerActivityCurvesCard> {
  _ActivityPointSelection? _selectedMainPoint;
  _ActivityPointSelection? _selectedFollowerPoint;
  String _activeMainCurveLabel = _allCurvesLabel;

  SellerActivitySnapshot get _snapshot => widget.snapshot;

  @override
  void didUpdateWidget(covariant SellerActivityCurvesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bucket count changes with the range, so a kept selection would point at
    // a stale position. Other host rebuilds keep the user's selection.
    if (oldWidget.snapshot.range != widget.snapshot.range) {
      _selectedMainPoint = null;
      _selectedFollowerPoint = null;
      _activeMainCurveLabel = _allCurvesLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final viewsColor = theme.colorScheme.tertiary;
    final productsColor = theme.colorScheme.secondary;
    final followersColor = theme.colorScheme.error;
    final mainChartLines = [
      _ActivityLineData(
        label: 'Likes',
        color: primary,
        values: _snapshot.likesCurve,
        actualValues: _snapshot.likesActual,
      ),
      _ActivityLineData(
        label: 'Vues',
        color: viewsColor,
        values: _snapshot.viewsCurve,
        actualValues: _snapshot.viewsActual,
      ),
      _ActivityLineData(
        label: 'Ajouts produit',
        color: productsColor,
        values: _snapshot.productAddsCurve,
        actualValues: _snapshot.productAddsActual,
      ),
    ];
    final followerLine = _ActivityLineData(
      label: 'Abonnés',
      color: followersColor,
      values: _snapshot.followersCurve,
      actualValues: _snapshot.followersActual,
    );

    final outlineColor = theme.appColors.inputBorder;
    final decoration =
        widget.decoration ??
        BoxDecoration(
          color: theme.appColors.panelBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: outlineColor),
        );
    // Chips sit directly on the card: transparent fill so they take the
    // card's own tone, outlined with the card's border color.
    final chipBorderColor = switch (decoration.border) {
      final Border border => border.top.color,
      _ => outlineColor,
    };
    final onRangeSelected = widget.onRangeSelected;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onRangeSelected != null) ...[
            SellerActivityRangeFilters(
              selected: _snapshot.range,
              onSelected: onRangeSelected,
              backgroundColor: Colors.transparent,
              borderColor: chipBorderColor,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Courbes d\'activité',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Suivi des abonnés, des likes, des vues et des ajouts de produit.',
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
          _buildAxisLabels(theme),
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
          _buildAxisLabels(theme),
        ],
      ),
    );
  }

  Widget _buildAxisLabels(ThemeData theme) {
    return Row(
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
    );
  }

  Widget _buildCurvePlot(
    ThemeData theme, {
    required List<_ActivityLineData> lines,
    required double height,
    required _ActivityPointSelection? selection,
    required ValueChanged<_ActivityPointSelection?> onPointSelected,
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
                    painter: _ActivityMultiLinePainter(
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
                    left: _tooltipLeft(
                      selection.position.dx,
                      constraints.maxWidth,
                    ),
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
    _ActivityPointSelection selection,
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
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  _ActivityPointSelection? _findNearestPoint({
    required Offset localPosition,
    required Size size,
    required List<_ActivityLineData> lines,
  }) {
    final chartRect = _ActivityChartGeometry.chartRectForSize(size);
    if (!chartRect.inflate(18).contains(localPosition)) {
      return null;
    }

    _ActivityPointSelection? bestMatch;
    var minDistance = double.infinity;

    for (final line in lines) {
      final points = _ActivityChartGeometry.pointsForLine(line.values, size);
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final distance = (point - localPosition).distance;
        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = _ActivityPointSelection(
            label: line.label,
            valueText: _formatCurveValue(line.label, line.actualValues[index]),
            position: point,
            color: line.color,
          );
        }
      }
    }

    return minDistance <= 28 ? bestMatch : null;
  }

  String _formatCurveValue(String label, int actualValue) {
    if (label == 'Ajouts produit') {
      return '$actualValue';
    }
    return _formatCompactNumber(actualValue);
  }

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      final compact = (value / 1000000).toStringAsFixed(
        value % 1000000 == 0 ? 0 : 1,
      );
      return '${compact}M';
    }
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
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

class _ActivityLineData {
  final String label;
  final Color color;
  final List<double> values;
  final List<int> actualValues;

  const _ActivityLineData({
    required this.label,
    required this.color,
    required this.values,
    required this.actualValues,
  });
}

class _ActivityPointSelection {
  final String label;
  final String valueText;
  final Offset position;
  final Color color;

  const _ActivityPointSelection({
    required this.label,
    required this.valueText,
    required this.position,
    required this.color,
  });
}

class _ActivityChartGeometry {
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

class _ActivityMultiLinePainter extends CustomPainter {
  final List<_ActivityLineData> lines;
  final Color gridColor;
  final _ActivityPointSelection? selectedPoint;
  final String? activeLineLabel;

  const _ActivityMultiLinePainter({
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

    final chartRect = _ActivityChartGeometry.chartRectForSize(size);

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

      final isDimmed =
          activeLineLabel != null &&
          activeLineLabel != _allCurvesLabel &&
          activeLineLabel != line.label;
      final effectiveColor = line.color.withValues(alpha: isDimmed ? 0.18 : 1);

      final points = _ActivityChartGeometry.pointsForLine(line.values, size);

      final fillPath = Path()..moveTo(points.first.dx, chartRect.bottom);
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        if (index == 0) {
          fillPath.lineTo(point.dx, point.dy);
        } else {
          final previous = points[index - 1];
          final controlX = (previous.dx + point.dx) / 2;
          fillPath.cubicTo(
            controlX,
            previous.dy,
            controlX,
            point.dy,
            point.dx,
            point.dy,
          );
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
        strokePath.cubicTo(
          controlX,
          previous.dy,
          controlX,
          point.dy,
          point.dx,
          point.dy,
        );
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
  bool shouldRepaint(covariant _ActivityMultiLinePainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.activeLineLabel != activeLineLabel;
  }
}
