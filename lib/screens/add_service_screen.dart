import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm; // اسم مستعار لخريطة flutter_map
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll; // اسم مستعار لإحداثيات الخريطة الحية
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm; // إحداثيات مشروعك الأساسية
import '../theme/app_colors.dart';
import '../data/service_repository.dart';
import '../models/service_model.dart';
import '../widgets/app_header.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final fm.MapController _miniMapController = fm.MapController();

  ServiceType? _selectedType;
  ServiceStatus _status = ServiceStatus.working;

  // الإحداثيات تبدأ افتراضياً من وسط قطاع غزة بنوع ll.LatLng المتوافق مع الخريطة المصغرة
  ll.LatLng _currentLocation = const ll.LatLng(31.4424, 34.3856);
  bool _hasLocation = false;
  bool _isSearching = false;

  // تايمر خاص بالبحث التلقائي (Debounce) عند الكتابة بحقل الموقع
  Timer? _debounceTimer;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchAndMoveToAddress(String address) async {
    String query = address.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    // 1. تحديد النطاق الجغرافي الإجباري لقطاع غزة (شمال، جنوب، شرق، غرب) لمنع الخروج منها
    final String gazaViewBox = "34.15,31.60,34.60,31.20";

    // دالة داخلية لتنفيذ الطلب الفعلي من السيرفر
    Future<List?> fetchFromOSM(String searchKey) async {
      final String fullQuery = "$searchKey, Gaza, Palestine";
      // ملاحظة: تم تصحيح الرابط هنا، كان يشير لدومين خاطئ (openstreetmap.org)
      // والصحيح هو استخدام خدمة Nominatim للبحث الجغرافي
      final String url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fullQuery)}&format=json&limit=1&viewbox=$gazaViewBox&bounded=1';
      try {
        final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'HSG_Humanitarian_App'});
        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
      } catch (e) {
        print("Error inside fetch: $e");
      }
      return null;
    }

    try {
      // محاولة أولى: البحث بالاسم الكامل الذي كتبه المستخدم
      List? data = await fetchFromOSM(query);

      // محاولة ثانية ذكية: إذا لم يجد نتائج (بسبب تداخل الكلمات أو خطأ إملائي)، يأخذ الكلمة الأولى فقط ويجربها
      if (data == null || data.isEmpty) {
        List<String> words = query.split(RegExp(r'[\s,_\-]+'));
        if (words.isNotEmpty && words[0].length > 2) {
          print("لم يتم العثور على العنوان الكامل، جاري التقريب باستخدام الكلمة الأولى: ${words[0]}");
          data = await fetchFromOSM(words[0]);
        }
      }

      // إذا نجحت المحاولة الأولى أو التقريبية الثانية
      if (data != null && data.isNotEmpty) {
        double lat = double.parse(data[0]['lat']);
        double lon = double.parse(data[0]['lon']);

        setState(() {
          _currentLocation = ll.LatLng(lat, lon);
          _hasLocation = true;
        });

        _miniMapController.move(_currentLocation, 15.0); // تقريب زووم الشاشة لرؤية واضحة للشوارع
        print("تم التقريب وتحديد الموقع بنجاح: $lat , $lon");
      } else {
        // إذا استحال العثور على الكلمات نهائياً، يثبت الدبوس في مركز غزة كـ Fallback بدلاً من الرفض
        setState(() {
          _currentLocation = const ll.LatLng(31.5150, 34.4500); // الرمال / وسط مدينة غزة الافتراضي
          _hasLocation = true; // نعتبرها true لنمكّن المستخدم من الحفظ ولا نعطله
        });
        _miniMapController.move(_currentLocation, 13.5);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exact location not found. Placed near Gaza Center automatically.")),
        );
      }
    } catch (e) {
      print("Error fetching location: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // يتم استدعاؤها عند كل تغيير بحقل النص، وتشغّل البحث تلقائياً بعد توقف المستخدم عن الكتابة
  void _onLocationTextChanged(String value) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 900), () {
      if (value.trim().length > 2) {
        _searchAndMoveToAddress(value);
      }
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final address = _locationController.text.trim();

    if (name.isEmpty || _selectedType == null || address.isEmpty || !_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter service name and search for a location.')),
      );
      return;
    }

    ServiceRepository.instance.addService(
      ServiceModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: _selectedType!,
        status: _status,
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        // بنخزن نص العنوان يلي بحثت عنه (أو كتبته يدوياً) عشان يظهر ببطاقة تفاصيل الخدمة عالخريطة لاحقاً
        address: address,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service added and marked successfully!'), backgroundColor: Colors.green),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Add Service'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service Name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter service name',
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Service Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              children: ServiceType.values.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  // عند اختيار نوع الخدمة، يُعاد رسم الدبوس على الخريطة بنفس الأيقونة واللون فوراً
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? type.color.withOpacity(0.12) : Colors.white,
                      border: Border.all(color: isSelected ? type.color : AppColors.fieldBorder, width: isSelected ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type.icon, color: type.color, size: 22),
                        const SizedBox(height: 4),
                        Text(type.label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statusChip('Working', Icons.check_circle, AppColors.accentGreen, ServiceStatus.working)),
                const SizedBox(width: 12),
                Expanded(child: _statusChip('Not working', Icons.cancel, AppColors.accentRed, ServiceStatus.notWorking)),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Location / Address in Gaza', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'Search or tap on the map below',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.hintGrey),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      suffixIcon: _isSearching
                          ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)))
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
                    ),
                    // بحث تلقائي أثناء الكتابة (بعد توقف قصير) بالإضافة للبحث عند الضغط على Enter
                    onChanged: _onLocationTextChanged,
                    onSubmitted: (value) => _searchAndMoveToAddress(value),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 22),
                    onPressed: () => _searchAndMoveToAddress(_locationController.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // تم التحديث هنا لتسجيل نقرات اليد مباشرة على الخريطة المصغرة لغزة
            Container(
              height: 230, // زدنا الارتفاع قليلاً لتسهيل اللمس والتحريك
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
                    initialZoom: 11.5,
                    // عند لمس أي نقطة في خريطة غزة، ينبثق الدبوس فوراً بأيقونة نوع الخدمة المختار
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentLocation = point;
                        _hasLocation = true; // نفعّلها لتسمح بالـ Submit فوراً
                        // نكتب الإحداثيات المحددة يدوياً داخل المربع لإعلام المستخدم
                        _locationController.text = "${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}";
                      });
                    },
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mapping',
                    ),
                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: _currentLocation,
                          width: 44,
                          height: 44,
                          // أيقونة ولون الدبوس هلأ تابعة لنوع الخدمة المختار (_selectedType)
                          // إذا ما في نوع مختار بعد، بيظهر دبوس افتراضي رمادي/أحمر عادي
                          child: Icon(
                            _selectedType?.icon ?? Icons.location_on,
                            color: _hasLocation ? (_selectedType?.color ?? Colors.red) : Colors.grey,
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
                "💡 Tip: You can also tap directly on the map to pin the exact location.",
                style: TextStyle(fontSize: 11, color: AppColors.hintGrey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, IconData icon, Color color, ServiceStatus value) {
    final isSelected = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
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
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
