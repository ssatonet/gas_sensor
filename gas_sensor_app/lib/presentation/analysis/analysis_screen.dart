import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gas_sensor_app/data/providers.dart';
import 'package:gas_sensor_app/data/models/models.dart';
import 'package:gas_sensor_app/presentation/analysis/analysis_providers.dart';
import 'package:gas_sensor_app/presentation/dashboard/equipment_detail_screen.dart';
import 'package:intl/intl.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipmentsAsync = ref.watch(siteEquipmentsProvider);
    final siteId = ref.watch(selectedSiteIdProvider);

    if (siteId == null) {
      return const Scaffold(
        body: Center(child: Text('工場を選択してください')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('サイト分析'),
      ),
      body: equipmentsAsync.when(
        data: (equipments) {
          if (equipments.isEmpty) {
            return const Center(child: Text('データがありません'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildJudgmentChart(ref),
                const SizedBox(height: 24),
                _buildTrendScatterPlot(context, ref),
                const SizedBox(height: 24),
                _buildAIInsights(ref),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildJudgmentChart(WidgetRef ref) {
    final analysisAsync = ref.watch(siteAnalysisProvider);

    return analysisAsync.when(
      data: (analysis) {
        final pass = analysis.passCount;
        final fail = analysis.criticalCount;
        final warning = analysis.warningCount;
        final unknown = analysis.unknownCount;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('判定分布 (Judgment Counts)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        if (pass > 0)
                          PieChartSectionData(
                            color: Colors.green,
                            value: pass.toDouble(),
                            title: '$pass',
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        if (fail > 0)
                          PieChartSectionData(
                            color: Colors.red,
                            value: fail.toDouble(),
                            title: '$fail',
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        if (warning > 0)
                          PieChartSectionData(
                            color: Colors.orange,
                            value: warning.toDouble(),
                            title: '$warning',
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                         if (unknown > 0)
                          PieChartSectionData(
                            color: Colors.grey,
                            value: unknown.toDouble(),
                            title: '$unknown',
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _LegendItem(color: Colors.green, label: '正常/合格 ($pass)'),
                    _LegendItem(color: Colors.red, label: '不合格/危険 ($fail)'),
                    _LegendItem(color: Colors.orange, label: '要注意 ($warning)'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Text('Error: $err'),
    );
  }

  Widget _buildTrendScatterPlot(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(siteInspectionsProvider);

    return inspectionsAsync.when(
      data: (historyList) {
        if (historyList.isEmpty) return const SizedBox.shrink();

        // Group by Model Name
        final byModel = <String, List<EquipmentInspectionHistory>>{};
        for (final h in historyList) {
          final model = h.equipment.modelName ?? 'Unknown Model';
          byModel.putIfAbsent(model, () => []).add(h);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('機種別 感度推移比較', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('機種ごとにグラフを表示しています。凡例をタップすると詳細画面へ移動します。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ...byModel.entries.map((entry) {
              final modelName = entry.key;
              final items = entry.value;
              return _buildModelChartCard(context, modelName, items);
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }

  Widget _buildModelChartCard(BuildContext context, String modelName, List<EquipmentInspectionHistory> items) {
    final lineBarsData = <LineChartBarData>[];
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, 
      Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan
    ];
    
    // Map to store color for each tag for the legend
    final legendItems = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final color = colors[i % colors.length];
      
      final spots = item.inspections.map((e) {
        return FlSpot(e.inspectionDate.millisecondsSinceEpoch.toDouble(), e.gasSensitivity ?? 0);
      }).toList();

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: color.withOpacity(0.7),
          barWidth: 2,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      );

      // Add Legend Item
      legendItems.add(
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EquipmentDetailScreen(equipment: item.equipment),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: color),
                const SizedBox(width: 4),
                Text(item.equipment.tagNo, style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(modelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: lineBarsData,
                  minY: 0,
                  maxY: 120,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('yy/MM').format(date), style: const TextStyle(fontSize: 10)),
                          );
                        },
                        interval: 1000 * 60 * 60 * 24 * 365 / 2, // Approx 6 months
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          // Find tag
                          String tag = '';
                          for (final item in items) {
                            if (item.inspections.any((e) => e.inspectionDate.millisecondsSinceEpoch.toDouble() == spot.x && e.gasSensitivity == spot.y)) {
                              tag = item.equipment.tagNo;
                              break;
                            }
                          }
                          
                          final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                          return LineTooltipItem(
                            '$tag\n${DateFormat('yyyy-MM-dd').format(date)}\n${spot.y.toStringAsFixed(1)}%',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('凡例 (タップで詳細へ):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: legendItems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInsights(WidgetRef ref) {
    final analysisAsync = ref.watch(siteAnalysisProvider);

    return analysisAsync.when(
      data: (analysis) {
        return Card(
          color: Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('AI インサイト (Beta)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
                const SizedBox(height: 12),
                if (analysis.anomalies.isNotEmpty)
                  Text('・要注意: ${analysis.anomalies.length} 台のセンサーが異常または交換時期です。', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                
                const SizedBox(height: 8),
                Text('・今後3ヶ月以内の交換予測: ${analysis.replacementForecast[3]} 台'),
                Text('・今後6ヶ月以内の交換予測: ${analysis.replacementForecast[6]} 台'),
                
                const SizedBox(height: 8),
                if (analysis.modelAverageLife.isNotEmpty)
                if (analysis.modelAverageLife.isNotEmpty)
                  ...analysis.modelAverageLife.entries.map((e) {
                    final months = e.value / 30;
                    final years = months / 12;
                    String timeStr;
                    if (e.value < 0) {
                      timeStr = "交換推奨 (超過)";
                    } else if (years >= 1) {
                      timeStr = "約 ${years.toStringAsFixed(1)} 年";
                    } else {
                      timeStr = "約 ${months.toStringAsFixed(1)} ヶ月";
                    }
                    return Text('・モデル ${e.key} の平均残寿命: $timeStr');
                  }),
                  
                if (analysis.anomalies.isEmpty && analysis.replacementForecast[3] == 0)
                   const Text('・現在、緊急性の高い異常は見当たりません。サイトの状態は良好です。'),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (err, stack) => Text('Error loading insights: $err'),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
