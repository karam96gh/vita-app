import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../patient/domain/models.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: context.t('appointments'),
    onRefresh: () async {
      ref.invalidate(appointmentsProvider);
      await ref.read(appointmentsProvider.future);
    },
    child: AsyncContent(
      value: ref.watch(appointmentsProvider),
      retry: () => ref.invalidate(appointmentsProvider),
      skeleton: const AppListSkeleton(count: 3, lines: 2),
      builder: (items) => items.isEmpty
          ? AppEmptyState(
              title: context.t('emptyAppointments'),
              hint: context.t('emptyAppointmentsHint'),
              icon: Icons.calendar_month_outlined,
            )
          : Column(
              children: [
                for (final (index, item) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppEntrance(
                      index: index,
                      child: AppointmentCard(appointment: item),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment});
  final Appointment appointment;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFEFE2),
                child: Icon(Icons.calendar_month, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.t(
                    appointment.type == 'SESSION' ? 'session' : 'appointments',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            AppDates.day(appointment.start, locale),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${AppDates.time(appointment.start, locale)} – ${AppDates.time(appointment.end, locale)}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (appointment.notes?.isNotEmpty == true) ...[
            const Divider(height: 28),
            Text(appointment.notes!),
          ],
        ],
      ),
    );
  }
}
