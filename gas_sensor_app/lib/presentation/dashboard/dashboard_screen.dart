import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_sensor_app/data/providers.dart';
import 'package:gas_sensor_app/presentation/dashboard/equipment_detail_screen.dart';

import 'package:gas_sensor_app/presentation/analysis/analysis_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);
    final selectedSiteId = ref.watch(selectedSiteIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ガス検知器 管理ダッシュボード'),
        actions: [
          // Site Selector
          sitesAsync.when(
            data: (sites) => DropdownButton<String>(
              value: selectedSiteId,
              hint: const Text('工場を選択'),
              items: sites.map((site) {
                return DropdownMenuItem(
                  value: site.id,
                  child: Text(site.name),
                );
              }).toList(),
              onChanged: (value) {
                ref.read(selectedSiteIdProvider.notifier).set(value);
              },
            ),
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text('Error: $err'),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AnalysisScreen()),
              );
            },
          ),

          const SizedBox(width: 20),
        ],
      ),
      body: selectedSiteId == null
          ? const Center(child: Text('工場を選択してください'))
          : const SingleChildScrollView(
              child: Column(
                children: [
                  EquipmentListSection(),
                ],
              ),
            ),
    );
  }
}



class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isBold;

  const _InfoChip({required this.label, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}

class EquipmentListSection extends ConsumerStatefulWidget {
  const EquipmentListSection({super.key});

  @override
  ConsumerState<EquipmentListSection> createState() => _EquipmentListSectionState();
}

class _EquipmentListSectionState extends ConsumerState<EquipmentListSection> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equipmentsAsync = ref.watch(sortedEquipmentsProvider);
    final currentSort = ref.watch(equipmentSortProvider);

    return equipmentsAsync.when(
      data: (equipments) {
        // Filter by search query
        final filteredEquipments = equipments.where((item) {
          final q = _searchQuery.toLowerCase();
          final eq = item.equipment;
          return eq.tagNo.toLowerCase().contains(q) ||
                 (eq.modelName?.toLowerCase().contains(q) ?? false) ||
                 (eq.serialNo?.toLowerCase().contains(q) ?? false);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: '検索 (TAG No, モデル, S/N)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('機器一覧 (${filteredEquipments.length}件)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  DropdownButton<SortOption>(
                    value: currentSort,
                    items: const [
                      DropdownMenuItem(value: SortOption.tagNo, child: Text('TAG No順')),
                      DropdownMenuItem(value: SortOption.danger, child: Text('危険度順')),
                      DropdownMenuItem(value: SortOption.sensitivity, child: Text('感度順')),
                      DropdownMenuItem(value: SortOption.daysRemaining, child: Text('交換予測順')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(equipmentSortProvider.notifier).set(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            
            if (filteredEquipments.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('該当する機器がありません'),
              ))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredEquipments.length,
                itemBuilder: (context, index) {
                  final item = filteredEquipments[index];
                  final eq = item.equipment;
                  
                  // Normal items are white/grey, Attention items get color
                  final isCritical = item.dangerLevel == 0;
                  final isWarning = item.dangerLevel == 1;
                  
                  Color cardColor = Colors.white;
                  Color textColor = Colors.black87;
                  Color iconColor = Colors.grey;
                  
                  if (isCritical) {
                    cardColor = Colors.red.shade50;
                    textColor = Colors.red.shade900;
                    iconColor = Colors.red;
                  } else if (isWarning) {
                    cardColor = Colors.orange.shade50;
                    textColor = Colors.orange.shade900;
                    iconColor = Colors.orange;
                  }

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12.0),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          isCritical || isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline, 
                          color: iconColor
                        ),
                      ),
                      title: Text(
                        'TAG: ${eq.tagNo}', // Tag No as primary
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Model and Serial No
                          Text('モデル: ${eq.modelName ?? "-"} / S/N: ${eq.serialNo ?? "-"}', 
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (item.latestInspection != null) ...[
                                _InfoChip(
                                  label: item.result,
                                  color: item.result == '合格' ? Colors.green : (item.result == '不合格' ? Colors.red : Colors.grey),
                                  isBold: true,
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  label: '感度: ${item.sensitivity.toStringAsFixed(1)}%',
                                  color: iconColor,
                                  isBold: true,
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (item.daysRemaining != null)
                                _InfoChip(
                                  label: 'あと ${item.daysRemaining} 日',
                                  color: iconColor,
                                  isBold: true,
                                )
                              else if (item.latestInspection != null)
                                _InfoChip(
                                  label: '予測不能',
                                  color: Colors.grey,
                                )
                              else
                                const _InfoChip(
                                  label: 'データなし',
                                  color: Colors.grey,
                                ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EquipmentDetailScreen(equipment: eq),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
