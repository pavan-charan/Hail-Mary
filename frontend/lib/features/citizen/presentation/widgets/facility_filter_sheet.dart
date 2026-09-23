import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme.dart';
import '../../state/citizen_map_notifier.dart';

class FacilityFilterSheet extends StatefulWidget {
  final CitizenMapFilter initialFilter;
  final int matchCount;
  final Function(CitizenMapFilter) onApply;

  const FacilityFilterSheet({
    super.key,
    required this.initialFilter,
    required this.matchCount,
    required this.onApply,
  });

  @override
  State<FacilityFilterSheet> createState() => _FacilityFilterSheetState();
}

class _FacilityFilterSheetState extends State<FacilityFilterSheet> {
  late String _category;
  late String _gender;
  late bool _wheelchairOnly;
  late double? _maxDistanceMeters;
  late bool _activeOnly;

  @override
  void initState() {
    super.initState();
    _category = widget.initialFilter.category;
    _gender = widget.initialFilter.gender;
    _wheelchairOnly = widget.initialFilter.wheelchairOnly;
    _maxDistanceMeters = widget.initialFilter.maxDistanceMeters;
    _activeOnly = widget.initialFilter.activeOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Facilities', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _category = 'ALL';
                      _gender = 'ALL';
                      _wheelchairOnly = false;
                      _maxDistanceMeters = null;
                      _activeOnly = false;
                    });
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 1. Facility Type
            Text('Facility Type', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFilterChoice('Category', 'ALL', 'All Types', Icons.layers_outlined),
                const SizedBox(width: 8),
                _buildFilterChoice('Category', 'TOILET', 'Restrooms', Icons.wc_outlined),
                const SizedBox(width: 8),
                _buildFilterChoice('Category', 'WATER', 'Drinking Water', Icons.water_drop_outlined),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Gender Access
            Text('Gender Access (For Restrooms)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChoice('Gender', 'ALL', 'All', Icons.people_outline),
                _buildFilterChoice('Gender', 'MALE', 'Male', Icons.man_outlined),
                _buildFilterChoice('Gender', 'FEMALE', 'Female', Icons.woman_outlined),
                _buildFilterChoice('Gender', 'UNISEX', 'Unisex', Icons.wc_outlined),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Distance Radius
            Text('Maximum Distance', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildDistanceChip(null, 'Any Distance'),
                _buildDistanceChip(500, '< 500m (Walkable)'),
                _buildDistanceChip(1000, '< 1 km'),
                _buildDistanceChip(3000, '< 3 km'),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Accessibility & Active Toggles
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Wheelchair Accessible Only', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
              secondary: const Icon(Icons.accessible_forward_rounded, color: AppTheme.primaryTeal),
              value: _wheelchairOnly,
              onChanged: (val) => setState(() => _wheelchairOnly = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Active & Operational Only', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
              secondary: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
              value: _activeOnly,
              onChanged: (val) => setState(() => _activeOnly = val),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final newFilter = CitizenMapFilter(
                  category: _category,
                  gender: _gender,
                  wheelchairOnly: _wheelchairOnly,
                  maxDistanceMeters: _maxDistanceMeters,
                  activeOnly: _activeOnly,
                );
                widget.onApply(newFilter);
                Navigator.pop(context);
              },
              child: Text('Apply Filters (${widget.matchCount} Available)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChoice(String group, String key, String label, IconData icon) {
    final isSelected = group == 'Category' ? _category == key : _gender == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryTeal),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal,
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.surfaceDark,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            if (group == 'Category') {
              _category = key;
            } else {
              _gender = key;
            }
          });
        }
      },
    );
  }

  Widget _buildDistanceChip(double? dist, String label) {
    final isSelected = _maxDistanceMeters == dist;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal,
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.surfaceDark,
      ),
      onSelected: (val) {
        if (val) setState(() => _maxDistanceMeters = dist);
      },
    );
  }
}
