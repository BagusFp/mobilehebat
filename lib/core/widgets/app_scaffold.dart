import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'status_badge.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showAppBar;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showVolcanoStatusBar;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.showAppBar = true,
    this.showBackButton = false,
    this.onBackTap,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showVolcanoStatusBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                      onPressed: onBackTap ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
              title: title != null
                  ? Text(
                      title!,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'lib/img/logo.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MerapiTrip',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
              actions: actions ??
                  [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                      onPressed: () {
                        // Dapat dinavigasikan ke Layar Notifikasi
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
              bottom: showVolcanoStatusBar
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        MediaQuery.textScalerOf(context).scale(34.0).clamp(32.0, 52.0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        width: double.infinity,
                        color: AppColors.volcanoStatusWaspadaBg.withAlpha(180),
                        child: Row(
                          children: [
                            const StatusBadge(
                              label: 'Merapi Level II (Waspada)',
                              type: VolcanicStatusType.waspada,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Jalur wisata Kaliurang & sekitarnya aman terkendali',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.volcanoStatusWaspada,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
