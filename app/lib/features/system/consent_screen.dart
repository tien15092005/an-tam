import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';
import '../../core/theme/tokens.dart';

const consentKey = 'consent_v1';

bool hasConsented(WidgetRef ref) => ref.read(sharedPreferencesProvider).getBool(consentKey) ?? false;

/// Shown once before anything else (plan §11): what An Tâm collects, why, where it goes, and the medical
/// disclaimer. Agreeing is the person's own choice; the app does not continue without it.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.navy),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleSmall),
                Text(body, style: text.bodyMedium),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text('Trước khi dùng An Tâm', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          point(Icons.person_outline, 'Thông tin thu thập',
              'Tên, email, số điện thoại của người con; tên gọi, năm sinh của bố mẹ; tên thuốc, giờ uống, ảnh thuốc, '
                  'các lần xác nhận uống thuốc, cảnh báo và tin nhắn trong nhóm. Không thu thập số đo sức khỏe.'),
          point(Icons.lock_outline, 'Ai xem được',
              'Chỉ các thành viên trong cùng nhóm gia đình. Quản trị hệ thống chỉ thấy số liệu tổng hợp, '
                  'không xem được thuốc, ảnh hay tin nhắn.'),
          point(Icons.document_scanner_outlined, 'Quét OCR',
              'Chữ được đọc trên điện thoại. Dòng có họ tên, địa chỉ, số điện thoại bị xóa trước khi gửi đi. '
                  'Ảnh giấy tờ không gửi lên máy chủ, trừ khi bạn chọn dùng ảnh làm ảnh thuốc.'),
          point(Icons.mic_none, 'Micro và thông báo',
              'Micro chỉ bật khi người già bấm nút nói. Thông báo dùng để nhắc thuốc và báo cho người con.'),
          point(Icons.delete_outline, 'Xóa dữ liệu',
              'Người con xóa được tài khoản và dữ liệu trong mục Cài đặt bất cứ lúc nào.'),
          Card(
            color: AppColors.warnSoft,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'An Tâm là công cụ nhắc lịch, không tư vấn y khoa và không đề xuất liều. Ảnh và mô tả thuốc chỉ để tham khảo; '
                'nếu nghi ngờ, hãy đối chiếu vỏ thuốc và hỏi dược sĩ, bác sĩ. Trường hợp nguy cấp, gọi 115.',
                style: text.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('consentAgree'),
            onPressed: () async {
              await ref.read(sharedPreferencesProvider).setBool(consentKey, true);
              if (context.mounted) context.go('/');
            },
            child: const Text('Tôi đã đọc và đồng ý'),
          ),
          TextButton(onPressed: () => SystemNavigator.pop(), child: const Text('Không đồng ý, thoát')),
        ]),
      ),
    );
  }
}
