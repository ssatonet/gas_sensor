import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gas_sensor_app/data/providers.dart';

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
          color: color.withValues(alpha: 0.7),
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
        // Find main model (highest count)
        String mainModel = '';
        int maxCount = -1;
        analysis.modelDistribution.forEach((k, v) {
          if (v > maxCount) {
            maxCount = v;
            mainModel = k;
          }
        });

        return Card(
          color: Colors.indigo.shade50,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                const SizedBox(height: 16),
                
                // 1. Data Scale
                _buildSectionHeader('データ規模'),
                _buildInfoRow('総点検レコード', '${analysis.totalRecords} 件'),
                _buildInfoRow('管理センサー数', '${analysis.totalSensors} 台'),
                _buildInfoRow('対象モデル', '${analysis.modelDistribution.length} 機種 (${analysis.modelDistribution.keys.join(", ")})'),
                const SizedBox(height: 16),

                // 2. Model Distribution
                _buildSectionHeader('機種分布'),
                ...analysis.modelDistribution.entries.map((e) {
                  final isMain = e.key == mainModel;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('・${e.key}: ${e.value} 台${isMain ? " (主力機種)" : ""}', style: const TextStyle(fontSize: 14)),
                  );
                }),
                const SizedBox(height: 16),

                // 3. Inspection Results
                _buildSectionHeader('点検結果状況'),
                _buildInfoRow('合格', '${analysis.totalPassRecords} 件'),
                Text(
                  '・不合格: ${analysis.totalFailRecords} 件 (全体の約${(analysis.totalRecords > 0 ? (analysis.totalFailRecords / analysis.totalRecords * 100) : 0).toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // 4. Average Sensitivity
                _buildSectionHeader('平均感度 (最新)'),
                ...analysis.modelAverageSensitivity.entries.map((e) {
                   String status = '良好';
                   Color color = Colors.green;
                   if (e.value < 88) {
                     status = 'やや低下傾向';
                     color = Colors.orange;
                   }
                   if (e.value < 60) {
                     status = '要交換';
                     color = Colors.red;
                   }
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 4.0),
                     child: Row(
                       children: [
                         Text('・${e.key}: ${e.value.toStringAsFixed(1)}% '),
                         Text('($status)', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   );
                }),
                 const SizedBox(height: 16),

                // 5. Attention Needed
                _buildSectionHeader('要注意センサー (直近で感度60%未満 または 不合格)'),
                if (analysis.anomalies.isEmpty)
                  const Text('・現在、要注意センサーはありません。', style: TextStyle(color: Colors.green)),
                if (analysis.anomalies.isNotEmpty)
                  ...analysis.anomalies.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '・TAGNO: ${a.tagNo} (${a.modelName}) - 感度 ${a.sensitivity.toStringAsFixed(1)}% (${DateFormat('yyyy/MM/dd').format(a.date)})\n  ※ ${a.reason}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (err, stack) => Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $err'))),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: TextDecoration.underline)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text('・$label: $value', style: const TextStyle(fontSize: 14)),
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
