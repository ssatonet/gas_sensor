import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_sensor_app/data/models/models.dart';
import 'package:gas_sensor_app/data/providers.dart';
import 'package:gas_sensor_app/presentation/inspection/inspection_input_screen.dart';
import 'package:intl/intl.dart';



class EquipmentDetailScreen extends ConsumerWidget {
  final EquipmentModel equipment;

  const EquipmentDetailScreen({super.key, required this.equipment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(inspectionsProvider(equipment.id));
    final predictionAsync = ref.watch(predictionProvider(equipment.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('機器詳細'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(equipment),
            const SizedBox(height: 20),
            const Text('感度推移グラフ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: inspectionsAsync.when(
                data: (inspections) => _buildChart(inspections, predictionAsync.value),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
            const SizedBox(height: 20),
            _buildPredictionCard(predictionAsync),
            const SizedBox(height: 20),
            const Text('点検履歴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            inspectionsAsync.when(
              data: (inspections) => _buildHistoryList(inspections, ref),
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InspectionInputScreen(equipment: equipment),
            ),
          );
        },
        label: const Text('点検入力'),
        icon: const Icon(Icons.edit_note),
      ),
    );
  }

  Widget _buildInfoCard(EquipmentModel eq) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('モデル: ${eq.modelName ?? "-"}'),
            Text('S/N: ${eq.serialNo ?? "-"}'),
            Text('ガス: ${eq.gasName ?? "-"}'),
            Text('検知原理: ${eq.sensorType ?? "-"}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(AsyncValue<Map<String, dynamic>?> predictionAsync) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('寿命予測', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            predictionAsync.when(
              data: (data) {
                if (data == null) return const Text('データ不足のため予測できません');
                final date = data['predicted_date'];
                final days = data['days_remaining'];
                if (date == null) return const Text('劣化傾向が見られません（良好）');
                
                final isOverdue = days != null && days < 0;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? '交換推奨日 (超過): $date' : '交換推奨日: $date',
                      style: TextStyle(fontSize: 18, color: isOverdue ? Colors.red : Colors.black, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOverdue ? '期限切れ: ${days.abs()} 日経過' : '残り日数: $days 日',
                      style: TextStyle(color: isOverdue ? Colors.red : Colors.black),
                    ),
                    if (isOverdue)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('※ データが古いため、推奨日が過去になっています。', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<InspectionModel> inspections, Map<String, dynamic>? prediction) {
    if (inspections.isEmpty) return const Center(child: Text('データがありません'));

    // Sort by date ascending for chart
    final sorted = List<InspectionModel>.from(inspections);
    sorted.sort((a, b) => a.inspectionDate.compareTo(b.inspectionDate));

    final points = sorted.asMap().entries.map((e) {
      final index = e.key;
      final item = e.value;
      // Use index as X for simplicity in this demo, ideally use date difference
      // But for linear regression visualization, let's stick to simple index or date timestamp
      return FlSpot(index.toDouble(), item.gasSensitivity ?? 0);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 120,
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          // Threshold Line (60%)
          LineChartBarData(
            spots: [
              const FlSpot(0, 60),
              FlSpot((points.length + 5).toDouble(), 60),
            ],
            color: Colors.red.withValues(alpha: 0.5),
            barWidth: 1,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sorted.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('yy/MM').format(sorted[index].inspectionDate),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<InspectionModel> inspections, WidgetRef ref) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: inspections.length,
      itemBuilder: (context, index) {
        final item = inspections[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(DateFormat('yyyy-MM-dd').format(item.inspectionDate)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item.gasSensitivity?.toStringAsFixed(1)} %'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('削除確認'),
                        content: const Text('この点検記録を削除しますか？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref.read(gasSensorRepositoryProvider).deleteInspection(item.id);
                        // Refresh providers
                        ref.invalidate(inspectionsProvider(equipment.id));
                        ref.invalidate(predictionProvider(equipment.id));
                        ref.invalidate(siteEquipmentsProvider); // Update main list too
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            subtitle: Text('判定: ${item.result ?? '-'}'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('点検詳細'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('点検日: ${DateFormat('yyyy-MM-dd').format(item.inspectionDate)}'),
                      const SizedBox(height: 8),
                      Text('感度: ${item.gasSensitivity?.toStringAsFixed(1)} %'),
                      Text('判定: ${item.result ?? '-'}'),
                      const Divider(),
                      Text('調整前: ${item.adjustmentBefore?.toStringAsFixed(1) ?? '-'}'),
                      Text('調整後: ${item.adjustmentAfter?.toStringAsFixed(1) ?? '-'}'),
                      const SizedBox(height: 8),
                      if (item.isSensorReplaced)
                        const Text('※ センサー交換実施', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
