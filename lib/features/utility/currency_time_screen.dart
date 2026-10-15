import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

import '../map/map_screen.dart';
import '../trip/my_trip_screen.dart';
import 'utility_provider.dart';

class CurrencyTimeScreen extends StatefulWidget {
  final String initialTab; // 'currency' atau 'time'

  const CurrencyTimeScreen({super.key, this.initialTab = 'currency'});

  @override
  State<CurrencyTimeScreen> createState() => _CurrencyTimeScreenState();
}

class _CurrencyTimeScreenState extends State<CurrencyTimeScreen> with SingleTickerProviderStateMixin {
  late String _activeTab;
  late TextEditingController _amountController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _amountController = TextEditingController(text: '100');
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(UtilityProvider provider) async {
    final now = provider.departureDateTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (pickedTime != null) {
      final newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      provider.setDepartureDateTime(newDateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilityProvider = context.watch<UtilityProvider>();



    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Konversi Mata Uang & Waktu',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.margin,
            AppDimensions.spaceSm,
            AppDimensions.margin,
            AppDimensions.spaceXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Context Status Bar: Merapi Hub Utility
              _buildContextBar(),
              const SizedBox(height: AppDimensions.spaceMd),

              // 2. Tab Switcher: Kurs Valuta vs Zona Waktu
              _buildTabSwitcher(),
              const SizedBox(height: AppDimensions.spaceLg),

              // 3. Tab Content
              if (_activeTab == 'currency')
                _buildCurrencyTab(context, utilityProvider)
              else
                _buildTimeTab(context, utilityProvider),

              const SizedBox(height: AppDimensions.spaceXl),

              // 4. Smart Navigation Links
              _buildSmartNavigationLinks(context),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Context Status Bar
  Widget _buildContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Merapi Hub Utility',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.signal_cellular_alt, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Mode Lapangan',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Tab Switcher
  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'currency'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'currency' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  boxShadow: _activeTab == 'currency'
                      ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      size: 18,
                      color: _activeTab == 'currency'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kurs Valuta',
                      style: AppTypography.labelLg.copyWith(
                        color: _activeTab == 'currency'
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 'time'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeTab == 'time' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  boxShadow: _activeTab == 'time'
                      ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: _activeTab == 'time'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Zona Waktu',
                      style: AppTypography.labelLg.copyWith(
                        color: _activeTab == 'time'
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: KURS VALUTA
  // --------------------------------------------------------------------------
  Widget _buildCurrencyTab(BuildContext context, UtilityProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Offline Cache Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tersimpan (Offline Cache)',
                        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Diperbarui: ${provider.lastSyncText}',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: RotationTransition(
                  turns: _spinController,
                  child: const Icon(Icons.sync, color: AppColors.primary, size: 20),
                ),
                onPressed: () async {
                  _spinController.forward(from: 0.0);
                  await provider.syncRates();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kurs valuta Merapi berhasil disinkronkan.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Currency Calculator Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Source Currency Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MATA UANG ASAL',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withAlpha(150),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            'Saldo Acuan',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: AppTypography.headlineLg.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: '0',
                            ),
                            onChanged: (val) {
                              final amount = double.tryParse(val) ?? 0.0;
                              provider.setSourceAmount(amount);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: provider.sourceCurrencyCode,
                              items: provider.availableCurrencies.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Text('${c.flag} ${c.code}', style: AppTypography.titleMd),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) provider.setSourceCurrency(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Swap Button
              Transform.translate(
                offset: const Offset(0, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        provider.swapCurrencies();
                      },
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(60),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.swap_vert, color: AppColors.onPrimary, size: 24),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Target Currency Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MATA UANG TUJUAN',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Lokal Wisata',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${provider.targetCurrency.code} (${provider.targetCurrency.name})',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: provider.targetCurrencyCode,
                              items: provider.availableCurrencies.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Text('${c.flag} ${c.code}', style: AppTypography.titleMd),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) provider.setTargetCurrency(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // 3. Conversion Output Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Column(
                  children: [
                    Text(
                      'HASIL KONVERSI SAAT INI',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.formattedConvertedResult,
                      style: AppTypography.headlineLg.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          provider.exchangeRateReferenceText,
                          style: AppTypography.labelMd.copyWith(color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // CTA: Apply to Merapi Trip Budget
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Kurs ${provider.sourceCurrencyCode} (${provider.formattedConvertedResult}) diterapkan ke acuan kalkulasi trip.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                  label: Text(
                    'Terapkan ke Estimasi Anggaran Trip',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLg),

        // Supported Currencies Grid
        Text(
          'Dukungan Kurs Wisman Merapi:',
          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: provider.availableCurrencies.take(4).map((c) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(c.code, style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold)),
                    Text(c.name, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: ZONA WAKTU
  // --------------------------------------------------------------------------
  Widget _buildTimeTab(BuildContext context, UtilityProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Sync Main Header Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Konverter Zona Waktu Perjalanan',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sinkronkan jadwal penerbangan internasional dengan jam trip lokal Merapi.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Date Time Selector Field
              InkWell(
                onTap: () => _pickDateTime(provider),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WAKTU ACUAN RENCANA BERANGKAT',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              provider.formattedDepartureWib,
                              style: AppTypography.titleMd.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_calendar, color: AppColors.onSurfaceVariant, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Timezone Comparison Cards
              // 1. Origin Traveler Zone
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withAlpha(120),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flight_takeoff, color: AppColors.onSurface, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zona Asal Traveler',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: provider.selectedTravelerTzId,
                              isDense: true,
                              items: provider.timezones.map((tz) {
                                return DropdownMenuItem<String>(
                                  value: tz.id,
                                  child: Text(
                                    tz.label,
                                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) provider.setSelectedTravelerTz(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          provider.formattedTravelerTime,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          provider.travelerTimeOfDayDescription,
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Merapi Local Destination Zone (WIB)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withAlpha(90),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.landscape, color: AppColors.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WIB (Gunung Merapi, UTC+7)',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tujuan Utama Tur',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          provider.formattedMerapiTime,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            provider.timeLagBadgeText,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Operational Notice Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.park, size: 20, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                          children: const [
                            TextSpan(
                              text: 'Petunjuk Operasional: ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            TextSpan(
                              text:
                                  'Loket tiket Bunker Kaliadem dan destinasi wisata resmi buka mengacu pada zona ',
                            ),
                            TextSpan(
                              text: 'WIB ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: '(06:00 – 16:30 WIB).'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Comprehensive Regional Timezone Badges Grid 2x2
              Text(
                'Referensi Cepat Zona Waktu:',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildTzBadge('WIB (UTC+7)', provider.getTimeForZone(0), isHighlight: true),
                  _buildTzBadge('WITA (UTC+8)', provider.getTimeForZone(1)),
                  _buildTzBadge('WIT (UTC+9)', provider.getTimeForZone(2)),
                  _buildTzBadge('London (BST)', provider.getTimeForZone(-6)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTzBadge(String zone, String time, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(zone, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
          Text(
            time,
            style: AppTypography.bodySm.copyWith(
              color: isHighlight ? AppColors.primary : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Smart Navigation Links
  Widget _buildSmartNavigationLinks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AKSES TERKAIT',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'MeraTrip Hub',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTripScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withAlpha(150),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.explore, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text('Rencana Trip', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Lihat estimasi rute lava tour', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.map, size: 18, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text('Peta Navigasi', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Peta LBS lereng Merapi', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
