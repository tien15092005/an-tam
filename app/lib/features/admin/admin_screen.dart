import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/tokens.dart';
import '../auth/session.dart';
import '../groups/code_dialog.dart' show confirm;

final _statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) async => (await ref.read(dioProvider).get<Map<String, dynamic>>('/api/admin/stats')).data!);

final _searchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, q) async {
  final r = await ref.read(dioProvider).get<List<dynamic>>('/api/admin/users', queryParameters: {'q': q});
  return r.data!.cast<Map<String, dynamic>>();
});

const _typeLabel = {'CAREGIVER': 'Người con', 'ELDER': 'Người già', 'SYSTEM_ADMIN': 'Quản trị'};

/// System admin (plan §10): totals, search, lock and unlock. Nothing here shows medicines, photos or chat.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _q = '';
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    final lock = !(u['disabled'] as bool);
    final ok = await confirm(context,
        title: lock ? 'Khóa tài khoản?' : 'Mở khóa?',
        message: lock ? '${u['displayName']} sẽ bị đăng xuất ngay trên mọi máy.' : '${u['displayName']} đăng nhập lại được.',
        action: lock ? 'Khóa' : 'Mở khóa');
    if (!ok) return;
    try {
      await ref.read(dioProvider).post<void>('/api/admin/users/${u['id']}/${lock ? 'disable' : 'enable'}');
      ref.invalidate(_searchProvider(_q));
      ref.invalidate(_statsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeNetworkError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = ref.watch(_statsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị An Tâm'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(_searchProvider(_q));
        },
        child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(describeNetworkError(e)),
            data: (s) {
              final byType = (s['usersByType'] as Map).cast<String, dynamic>();
              Widget tile(String label, Object value, {Color? color}) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$value', style: text.headlineSmall?.copyWith(color: color)),
                        Text(label, style: text.bodySmall),
                      ]),
                    ),
                  );
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  tile('Người con', byType['CAREGIVER'] ?? 0),
                  tile('Người già', byType['ELDER'] ?? 0),
                  tile('Nhóm gia đình', s['groups']),
                  tile('Cảnh báo chưa xử lý', s['openAlerts'], color: AppColors.danger),
                  tile('Cảnh báo 7 ngày qua', s['alertsLast7Days']),
                  tile('Tài khoản bị khóa', s['disabledUsers']),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _input,
            decoration: const InputDecoration(labelText: 'Tìm theo tên hoặc email', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
          const SizedBox(height: AppSpacing.sm),
          ref.watch(_searchProvider(_q)).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(describeNetworkError(e)),
                data: (list) => Column(children: [
                  for (final u in list)
                    Card(
                      child: ListTile(
                        leading: Icon(u['disabled'] == true ? Icons.lock : Icons.person,
                            color: u['disabled'] == true ? AppColors.danger : AppColors.navy),
                        title: Text(u['displayName'] as String),
                        subtitle: Text([
                          _typeLabel[u['accountType']] ?? '',
                          if (u['email'] != null) u['email'] as String,
                          '${u['groups']} nhóm',
                        ].join(' · ')),
                        trailing: u['accountType'] == 'SYSTEM_ADMIN'
                            ? null
                            : TextButton(
                                onPressed: () => _toggle(u),
                                child: Text(u['disabled'] == true ? 'Mở khóa' : 'Khóa'),
                              ),
                      ),
                    ),
                ]),
              ),
          const SizedBox(height: AppSpacing.md),
          Text('Quản trị chỉ thấy số liệu tổng hợp và tài khoản, không xem được thuốc, ảnh, tin nhắn hay lịch uống.',
              style: text.bodySmall),
        ]),
      ),
    );
  }
}
