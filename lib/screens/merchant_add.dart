import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker_web/image_picker_web.dart';
import '../widgets/merchant_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

// Remove or comment out the Supabase client
// final supabase = Supabase.instance.client;

class ServiceAddScreen extends StatefulWidget {
  const ServiceAddScreen({Key? key}) : super(key: key);

  @override
  State<ServiceAddScreen> createState() => _ServiceAddScreenState();
}

class _ServiceAddScreenState extends State<ServiceAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  List<dynamic> _images = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  final int _maxImageSize = 5 * 1024 * 1024; // 5MB
  late drive.DriveApi _driveApi;
  String? _appFolderId;
  bool _acceptsOnlinePayment = false;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadCategories();
      }
    });
  }

  Future<void> _initializeDriveApi() async {
    // Load the JSON file
    final jsonString = await rootBundle.loadString('assets/credentials/cobalt-ion-442107-b8-f8666a191395.json');
    final credentials = ServiceAccountCredentials.fromJson(json.decode(jsonString));
    
    final client = await clientViaServiceAccount(
      credentials, 
      [drive.DriveApi.driveFileScope]
    );
    _driveApi = drive.DriveApi(client);
    await _getOrCreateAppFolder();
  }

  Future<void> _getOrCreateAppFolder() async {
    // Search for existing folder
    var folderList = await _driveApi.files.list(
      q: "name='StorageTestApp' and mimeType='application/vnd.google-apps.folder'",
      spaces: 'drive',
    );

    if (folderList.files?.isNotEmpty == true) {
      _appFolderId = folderList.files!.first.id;
    } else {
      // Create new folder
      var folder = drive.File()
        ..name = 'StorageTestApp'
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi.files.create(folder);
      _appFolderId = createdFolder.id;

      // Make folder publicly readable
      await _driveApi.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        _appFolderId!,
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await ImagePickerWeb.getMultiImagesAsBytes();
      if (result != null) {
        for (var imageData in result) {
          // Check file size
          if (imageData.length > _maxImageSize) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).translate('image_too_large'))),
            );
            continue;
          }

          // Ensure we're working with Uint8List
          final Uint8List imageBytes = imageData is Uint8List 
              ? imageData 
              : Uint8List.fromList(imageData);

          setState(() {
            _images.add(imageBytes);
          });
        }
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('error_picking_images')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return file;

    // Compress the image
    final compressedImage = img.encodeJpg(image, quality: 70);
    
    // Save the compressed image
    final tempDir = await Directory.systemTemp.create();
    final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(compressedImage);
    
    return tempFile;
  }

  Future<List<String>> _uploadImages() async {
    if (_appFolderId == null) {
      throw Exception('Drive folder not initialized');
    }

    List<String> imageUrls = [];
    int totalImages = _images.length;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    for (var i = 0; i < _images.length; i++) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        // Convert image to bytes
        final bytes = _images[i] is Uint8List 
            ? _images[i] 
            : await _images[i].readAsBytes();

        // Create Drive file metadata
        var driveFile = drive.File()
          ..name = fileName
          ..parents = [_appFolderId!]
          ..mimeType = 'image/jpeg';

        // Upload file
        final response = await _driveApi.files.create(
          driveFile,
          uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
        );

        // Make the file publicly accessible
        await _driveApi.permissions.create(
          drive.Permission()
            ..type = 'anyone'
            ..role = 'reader',
          response.id!,
        );

        // Get the web view link
        final webViewLink = 'https://drive.google.com/uc?id=${response.id}';
        imageUrls.add(webViewLink);
        
        setState(() {
          _uploadProgress = ((i + 1) / totalImages * 100).round();
        });

      } catch (e, stackTrace) {
        print('Error uploading image: $e');
        print('Stack trace: $stackTrace');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        continue;
      }
    }
    
    setState(() {
      _isUploading = false;
    });
    
    if (imageUrls.isEmpty) {
      throw Exception('No images were uploaded successfully');
    }
    
    return imageUrls;
  }

  Future<void> _submitForm() async {
    if (_images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('minimum_images_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('select_category')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedCategory = _categories.firstWhere(
        (cat) => cat['id'] == _selectedCategoryId,
        orElse: () => throw Exception('Category not found'),
      );

      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      await FirebaseFirestore.instance.collection('services').add({
        'providerName': _providerNameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'categoryId': _selectedCategoryId,
        'category_en': selectedCategory['name_en'],
        'category_ar': selectedCategory['name_ar'],
        'images': imageUrls,
        'merchantId': FirebaseAuth.instance.currentUser?.uid,
        'acceptsOnlinePayment': _acceptsOnlinePayment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('service_added_success'))),
      );
      
      // Clear form
      _providerNameController.clear();
      _locationController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _selectedCategoryId = null;
        _images = [];
        _isLoading = false;
        _acceptsOnlinePayment = false;
      });
    } catch (e) {
      print('Error submitting form: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('error_adding_service')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      // First check if categories exist
      final categoriesRef = FirebaseFirestore.instance.collection('service_categories');
      final snapshot = await categoriesRef.get();

      if (snapshot.docs.isEmpty) {
        // Create default categories if none exist
        final defaultCategories = [
          {
            'name_en': 'Diving activities',
            'name_ar': 'أنشطة الغوص',
            'order': 1,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name_en': 'Snorkeling activities',
            'name_ar': 'أنشطة الغطس',
            'order': 2,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name_en': 'Safari activities',
            'name_ar': 'أنشطة السفاري',
            'order': 3,
            'createdAt': FieldValue.serverTimestamp(),
          },
          {
            'name_en': 'Nightlife activities',
            'name_ar': 'أنشطة الحياة الليلية',
            'order': 4,
            'createdAt': FieldValue.serverTimestamp(),
          },
        ];

        // Add categories one by one
        for (var category in defaultCategories) {
          try {
            await categoriesRef.add(category);
          } catch (e) {
            print('Error adding category: $e');
          }
        }
      }

      // Fetch categories again after potentially creating them
      final categoriesSnapshot = await categoriesRef
          .orderBy('order')
          .get();

      if (mounted) {
        setState(() {
          _categories = categoriesSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name_en': doc.data()['name_en'] ?? '',
              'name_ar': doc.data()['name_ar'] ?? '',
              'order': doc.data()['order'] ?? 0,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_categories')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImagePicker() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).translate('service_images'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${AppLocalizations.of(context).translate('minimum_3_images')})',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _images.length < 3 
                ? colorScheme.error.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DottedBorder(
            borderType: BorderType.RRect,
            radius: const Radius.circular(12),
            color: _images.length < 3 
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            strokeWidth: 2,
            dashPattern: const [8, 4],
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: colorScheme.surface,
                child: Column(
                  children: [
                    // Display selected images
                    if (_images.isNotEmpty) ...[
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Stack(
                                children: [
                                  _buildImagePreview(_images[index]),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        color: Colors.white,
                                        onPressed: () {
                                          setState(() {
                                            _images.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Add image button
                    TextButton.icon(
                      onPressed: _pickImages,
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _images.length < 3 ? Colors.red : Colors.grey[600],
                      ),
                      label: Text(
                        _images.isEmpty
                            ? AppLocalizations.of(context).translate('add_images')
                            : AppLocalizations.of(context).translate('add_more_images'),
                        style: TextStyle(
                          color: _images.length < 3 ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (_images.length < 3) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_images.length}/3 ${AppLocalizations.of(context).translate('images_added')}',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _uploadProgress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFe2211c)),
          ),
          const SizedBox(height: 8),
          Text('${AppLocalizations.of(context).translate('uploading')} $_uploadProgress%'),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('category'),
        prefixIcon: Icon(Icons.category, color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface),
      items: _categories.map((category) {
        return DropdownMenuItem<String>(
          value: category['id'],
          child: Text(
            isArabic ? category['name_ar'] : category['name_en'],
            style: TextStyle(color: colorScheme.onSurface),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategoryId = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('required_field');
        }
        return null;
      },
    );
  }

  Widget _buildImagePreview(dynamic imageData) {
    if (imageData is Uint8List) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: MemoryImage(imageData),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Fallback for unsupported image type
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: Colors.grey[400],
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefix,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(labelText),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(color: colorScheme.onSurface),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('required_field');
        }
        if (labelText == 'price') {
          final price = double.tryParse(value);
          if (price == null || price <= 0) {
            return AppLocalizations.of(context).translate('invalid_price');
          }
        }
        return null;
      },
    );
  }

  Widget _buildOnlinePaymentToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payment,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('accepts_online_payment'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
          ),
          Switch(
            value: _acceptsOnlinePayment,
            onChanged: (bool value) {
              setState(() {
                _acceptsOnlinePayment = value;
              });
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                MerchantAppBar(titleKey: 'add_service'),
                if (_isUploading) _buildUploadProgress(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _providerNameController,
                            labelText: 'provider_name',
                            icon: Icons.business,
                          ),
                          const SizedBox(height: 20),
                          _buildCategoryDropdown(),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _priceController,
                            labelText: 'price',
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            prefix: 'EGP ',
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _locationController,
                            labelText: 'location',
                            icon: Icons.location_on,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _descriptionController,
                            labelText: 'description',
                            icon: Icons.description,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          _buildOnlinePaymentToggle(),
                          const SizedBox(height: 24),
                          _buildImagePicker(),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitForm,
                              icon: Icon(_isLoading ? null : Icons.add_circle_outline),
                              label: _isLoading
                                  ? CircularProgressIndicator(
                                      color: colorScheme.onPrimary,
                                    )
                                  : Text(
                                      AppLocalizations.of(context).translate('add_service'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading && !_isUploading)
              Container(
                color: colorScheme.background.withOpacity(0.7),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _providerNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}