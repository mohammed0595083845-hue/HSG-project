import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../data/category_repository.dart';
import '../data/service_repository.dart';
import '../models/category_model.dart';
import '../models/location_model.dart';
import '../models/service_model.dart';
import '../widgets/app_header.dart';

class AddServiceScreen extends StatefulWidget {
  /// لو تم تمريرها: وضع التعديل (editOwnService)
  final ServiceModel? existing;

  const AddServiceScreen({super.key, this.existing});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final fm.MapController _miniMapController = fm.MapController();

  String? _selectedCategoryId;
  Availability _availability = Availability.working;
  final List<CategoryModel> _extraCategories = [];

  ll.LatLng _currentLocation = const ll.LatLng(31.4424, 34.3856);
  bool _hasLocation = false;
  bool _isSearching = false;
  bool _isSaving = false;

  Timer? _debounceTimer;
  int _searchToken = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _nameController.text = s.serviceName;
      _descriptionController.text = s.description;
      _selectedCategoryId = s.categoryId;
      _availability = s.availability;
      _currentLocation = ll.LatLng(s.location.latitude, s.location.longitude);
      _hasLocation = true;
      _locationController.text = s.location.address.isNotEmpty
          ? s.location.address
          : '${s.location.latitude.toStringAsFixed(5)}, ${s.location.longitude.toStringAsFixed(5)}';
      _extraCategories.add(CategoryRepository.instance.byId(s.categoryId));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ───────────── البحث عن العنوان (Nominatim) ─────────────

  Future<List?> _fetchFromOSM(String searchKey) async {
    const gazaViewBox = '34.15,31.60,34.60,31.20';
    final fullQuery = '$searchKey, Gaza, Palestine';
    final url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fullQuery)}&format=json&limit=1&viewbox=$gazaViewBox&bounded=1';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'HSG_Humanitarian_App'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as List;
      }
    } catch (e) {
      debugPrint('OSM fetch error: $e');
    }
    return null;
  }

  Future<void> _searchAndMoveToAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty) return;

    final token = ++_searchToken;
    setState(() => _isSearching = true);

    List? data = await _fetchFromOSM(query);

    // محاولة تقريبية بالكلمة الأولى (مع انتظار ثانية احتراماً لحدود Nominatim)
    if (data == null || data.isEmpty) {
      final words = query.split(RegExp(r'[\s,_\-]+'));
      if (words.isNotEmpty && words[0].length > 2) {
        await Future.delayed(const Duration(seconds: 1));
        data = await _fetchFromOSM(words[0]);
      }
    }

    // لو المستخدم كتب شي جديد أو سكّر الشاشة، نتجاهل هالنتيجة
    if (!mounted || token != _searchToken) return;

    if (data != null && data.isNotEmpty) {
      final lat = double.parse(data[0]['lat'] as String);
      final lon = double.parse(data[0]['lon'] as String);
      setState(() {
        _currentLocation = ll.LatLng(lat, lon);
        _hasLocation = true;
        _isSearching = false;
      });
      _miniMapController.move(_currentLocation, 15.0);
    } else {
      setState(() {
        _currentLocation = const ll.LatLng(31.5150, 34.4500);
        _hasLocation = true;
        _isSearching = false;
      });
      _miniMapController.move(_currentLocation, 13.5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exact location not found. Placed near Gaza Center automatically.',
          ),
        ),
      );
    }
  }

  void _onLocationTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 900), () {
      if (value.trim().length > 2) _searchAndMoveToAddress(value);
    });
  }

  // ───────────── اقتراح فئة جديدة ─────────────

  Future<void> _suggestCategory() async {
    final nameController = TextEditingController();
    String icon = 'place';
    String color = CategoryModel.colorOptions.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Category name'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Icon',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CategoryModel.iconOptions.entries.map((e) {
                    final selected = icon == e.key;
                    return GestureDetector(
                      onTap: () => setLocal(() => icon = e.key),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.primaryBlue.withOpacity(0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryBlue
                                : AppColors.fieldBorder,
                          ),
                        ),
                        child: Icon(
                          e.value,
                          size: 20,
                          color: AppColors.darkNavy,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: CategoryModel.colorOptions.map((hex) {
                    final selected = color == hex;
                    return GestureDetector(
                      onTap: () => setLocal(() => color = hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CategoryModel.parseColor(hex),
                          border: Border.all(
                            color: selected ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A new category needs admin approval before everyone can use it.',
                  style: TextStyle(fontSize: 11, color: AppColors.hintGrey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    if (confirmed != true || name.isEmpty) return;

    final category = await CategoryRepository.instance.suggestCategory(
      name: name,
      icon: icon,
      color: color,
    );
    if (!mounted) return;

    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the category. Please try again.'),
        ),
      );
      return;
    }

    setState(() {
      _extraCategories.add(category);
      _selectedCategoryId = category.categoryId;
    });
  }

  // ───────────── الحفظ ─────────────

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final address = _locationController.text.trim();

    if (name.isEmpty ||
        _selectedCategoryId == null ||
        address.isEmpty ||
        !_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter service name, choose a type and set a location.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repo = ServiceRepository.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    final location = LocationModel(
      locationId: widget.existing?.location.locationId ?? 'loc_$now',
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      address: address,
    );

    final bool ok;
    if (_isEdit) {
      ok = await repo.editOwnService(widget.existing!.serviceId, {
        'serviceName': name,
        'categoryId': _selectedCategoryId,
        'description': _descriptionController.text.trim(),
        'availability': _availability.name,
        'locationId': location.locationId,
        'location': location.toMap(),
      });
    } else {
      ok = await repo.addService(
        ServiceModel(
          serviceId: now.toString(),
          serviceName: name,
          status: ServiceStatus.pending, // لازم موافقة الأدمن
          createdBy: uid,
          categoryId: _selectedCategoryId!,
          location: location,
          description: _descriptionController.text.trim(),
          availability: _availability,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Could not update (only your Pending services can be edited).'
                : 'Could not save the service. Please try again.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEdit
              ? 'Service updated.'
              : 'Service submitted for admin approval.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  // ───────────── الواجهة ─────────────

  List<CategoryModel> _categoryOptions(List<CategoryModel> all) {
    final options = all.where((c) => c.isDefault).toList();
    for (final extra in _extraCategories) {
      if (!options.any((c) => c.categoryId == extra.categoryId))
        options.add(extra);
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _selectedCategoryId == null
        ? null
        : CategoryRepository.instance.byId(_selectedCategoryId!);

    return Scaffold(
      appBar: AppHeader(title: _isEdit ? 'Edit Service' : 'Add Service'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Name',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _textField(_nameController, 'Enter service name'),
            const SizedBox(height: 20),

            const Text(
              'Service Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<CategoryModel>>(
              valueListenable: CategoryRepository.instance.categories,
              builder: (context, all, _) {
                final options = _categoryOptions(all);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [...options.map(_categoryTile), _newCategoryTile()],
                );
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _textField(
              _descriptionController,
              'Describe the service (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _availabilityChip(
                    'Working',
                    Icons.check_circle,
                    AppColors.accentGreen,
                    Availability.working,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _availabilityChip(
                    'Not working',
                    Icons.cancel,
                    AppColors.accentRed,
                    Availability.notWorking,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Location / Address in Gaza',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'Search or tap on the map below',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.hintGrey,
                      ),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: _border(),
                      enabledBorder: _border(),
                    ),
                    onChanged: _onLocationTextChanged,
                    onSubmitted: _searchAndMoveToAddress,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () =>
                        _searchAndMoveToAddress(_locationController.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.fieldBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: fm.FlutterMap(
                  mapController: _miniMapController,
                  options: fm.MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: _isEdit ? 15 : 11.5,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentLocation = point;
                        _hasLocation = true;
                        _locationController.text =
                            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                      });
                    },
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mapping',
                    ),
                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: _currentLocation,
                          width: 44,
                          height: 44,
                          child: Icon(
                            selectedCategory?.iconData ?? Icons.location_on,
                            color: _hasLocation
                                ? (selectedCategory?.colorValue ?? Colors.red)
                                : Colors.grey,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '💡 Tip: You can also tap directly on the map to pin the exact location.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.hintGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save Changes' : 'Submit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.fieldBorder),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.fieldFill,
        border: _border(),
        enabledBorder: _border(),
      ),
    );
  }

  Widget _categoryTile(CategoryModel c) {
    final isSelected = _selectedCategoryId == c.categoryId;
    final color = c.colorValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = c.categoryId),
      child: Container(
        width: 64,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          border: Border.all(
            color: isSelected ? color : AppColors.fieldBorder,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(c.iconData, color: color, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                c.name,
                style: const TextStyle(fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newCategoryTile() {
    return GestureDetector(
      onTap: _suggestCategory,
      child: Container(
        width: 64,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.fieldBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.hintGrey, size: 22),
            SizedBox(height: 4),
            Text(
              'New',
              style: TextStyle(fontSize: 9, color: AppColors.hintGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _availabilityChip(
    String label,
    IconData icon,
    Color color,
    Availability value,
  ) {
    final isSelected = _availability == value;
    return GestureDetector(
      onTap: () => setState(() => _availability = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          border: Border.all(color: isSelected ? color : AppColors.fieldBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
