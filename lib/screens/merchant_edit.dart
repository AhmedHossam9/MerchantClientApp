import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import '../widgets/merchant_app_bar.dart';
import '../utils/app_localizations.dart';
import '../widgets/loading_overlay.dart';

class MerchantEditScreen extends StatefulWidget {
  const MerchantEditScreen({Key? key}) : super(key: key);

  @override
  State<MerchantEditScreen> createState() => _MerchantEditScreenState();
}

class _MerchantEditScreenState extends State<MerchantEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  
  List<String> _existingImages = [];
  List<XFile> _newImages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  String? _itemId;
  
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  String? _folderId;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _itemId = args?['itemId'];
      if (_itemId != null) {
        _initializeDriveApi().then((_) {
          if (mounted) {
            _loadCategories();
            _loadItemData();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manufacturerController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _authClient?.close();
    super.dispose();
  }

  Future<void> _initializeDriveApi() async {
    try {
      final jsonString = await rootBundle.loadString('assets/credentials/cobalt-ion-442107-b8-f8666a191395.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(jsonString));
      _authClient = await clientViaServiceAccount(credentials, [drive.DriveApi.driveFileScope]);
      _driveApi = drive.DriveApi(_authClient!);
    } catch (e) {
      print('Error initializing Drive API: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('order')
          .get();
      
      if (mounted) {
        setState(() {
          _categories = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name_en': data['name_en'] as String? ?? '',
              'name_ar': data['name_ar'] as String? ?? '',
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

  Future<void> _loadItemData() async {
    if (_isDataLoaded) return;

    try {
      // Load categories first
      await _loadCategories();

      final doc = await FirebaseFirestore.instance
          .collection('items')
          .doc(_itemId)
          .get();
      
      if (!doc.exists) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).translate('item_not_found')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final data = doc.data()!;
      
      // Verify the category exists in loaded categories
      final categoryId = data['categoryId'] as String?;
      final categoryExists = _categories.any((cat) => cat['id'] == categoryId);
      
      if (mounted) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _manufacturerController.text = data['manufacturer'] ?? '';
          _quantityController.text = (data['quantity'] ?? '').toString();
          _priceController.text = (data['price'] ?? '').toString();
          _descriptionController.text = data['description'] ?? '';
          _selectedCategoryId = categoryExists ? categoryId : null;
          _existingImages = List<String>.from(data['images'] ?? []);
          _isLoading = false;
          _isDataLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading item data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_item')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('fix_form_errors')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _newImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_picking_images')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeExistingImage(int index) async {
    final totalImages = _existingImages.length + _newImages.length;
    
    if (totalImages <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('minimum_three_images_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final url = _existingImages[index];
      String fileId;
      if (url.contains('id=')) {
        fileId = url.split('id=').last;
      } else {
        fileId = url.split('/d/').last.split('/').first;
      }
      
      await _driveApi.files.delete(fileId);
      
      setState(() {
        _existingImages.removeAt(index);
      });
    } catch (e) {
      print('Error removing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_removing_image')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getOrCreateFolder() async {
    if (_folderId != null) return _folderId!;

    try {
      // Search for existing folder
      var folderList = await _driveApi.files.list(
        q: "name='StorageTestApp' and mimeType='application/vnd.google-apps.folder'",
        spaces: 'drive',
      );

      if (folderList.files?.isNotEmpty == true) {
        _folderId = folderList.files!.first.id;
        print('Found existing folder: $_folderId');
        return _folderId!;
      }

      // Create new folder if it doesn't exist
      var folder = drive.File()
        ..name = 'StorageTestApp'
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi.files.create(folder);
      _folderId = createdFolder.id!;

      // Make folder publicly readable
      await _driveApi.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        _folderId!,
      );

      print('Created new folder: $_folderId');
      return _folderId!;
    } catch (e) {
      print('Error getting/creating folder: $e');
      throw Exception('Failed to get/create folder');
    }
  }

  Future<List<String>> _uploadNewImages() async {
    List<String> newImageUrls = [];
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      // Get or create the folder first
      final folderId = await _getOrCreateFolder();

      for (var i = 0; i < _newImages.length; i++) {
        try {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final bytes = await _newImages[i].readAsBytes();

          var driveFile = drive.File()
            ..name = fileName
            ..parents = [folderId]  // Use the retrieved folder ID
            ..mimeType = 'image/jpeg';

          final response = await _driveApi.files.create(
            driveFile,
            uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
          );

          await _driveApi.permissions.create(
            drive.Permission()
              ..type = 'anyone'
              ..role = 'reader',
            response.id!,
          );

          final webViewLink = 'https://drive.google.com/uc?id=${response.id}';
          newImageUrls.add(webViewLink);
          
          setState(() {
            _uploadProgress = ((i + 1) / _newImages.length * 100).round();
          });
        } catch (e) {
          print('Error uploading image: $e');
        }
      }
    } catch (e) {
      print('Error in _uploadNewImages: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }

    return newImageUrls;
  }

  Future<void> _saveChanges() async {
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

    final totalImages = _existingImages.length + _newImages.length;
    if (totalImages < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('minimum_three_images_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Find selected category data
      final selectedCategory = _categories.firstWhere(
        (cat) => cat['id'] == _selectedCategoryId
      );

      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        newImageUrls = await _uploadNewImages();
      }

      final allImages = [..._existingImages, ...newImageUrls];

      await FirebaseFirestore.instance
          .collection('items')
          .doc(_itemId)
          .update({
        'name': _nameController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'categoryId': _selectedCategoryId,
        'category_en': selectedCategory['name_en'],
        'category_ar': selectedCategory['name_ar'],
        'images': allImages,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('changes_saved'))),
        );
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('error_saving_changes'))),
        );
      }
    }
  }

  Widget _buildExistingImageWidget(String imageUrl) {
    String fileId;
    if (imageUrl.contains('id=')) {
      fileId = imageUrl.split('id=').last;
    } else {
      fileId = imageUrl.split('/d/').last.split('/').first;
    }

    final mediaUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    final token = _authClient?.credentials.accessToken.data;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          headers: {
            'Authorization': 'Bearer $token',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewImagePreview(XFile image) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 32,
            ),
          );
        }

        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: MemoryImage(snapshot.data!),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing Images Section
        if (_existingImages.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context).translate('existing_images'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      _buildExistingImageWidget(_existingImages[index]),
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
                              final totalImages = _existingImages.length + _newImages.length;
                              if (totalImages <= 3) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context).translate('minimum_three_images_required')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              _removeExistingImage(index);
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
          const SizedBox(height: 24),
        ],

        // New Images Section
        if (_newImages.isNotEmpty) ...[
          Text(
            AppLocalizations.of(context).translate('new_images'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _newImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      _buildNewImagePreview(_newImages[index]),
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
                              final totalImages = _existingImages.length + _newImages.length;
                              if (totalImages <= 3) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context).translate('minimum_three_images_required')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                _newImages.removeAt(index);
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
        ],

        // Add Images Button
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[700]),
          label: Text(
            AppLocalizations.of(context).translate('add_more_images'),
            style: TextStyle(color: Colors.grey[700]),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[400]!),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateWithLoading(String route, [Map<String, dynamic>? arguments]) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      
      try {
        if (arguments != null) {
          await Navigator.pushNamed(context, route, arguments: arguments);
        } else {
          await Navigator.pushNamed(context, route);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            body: SafeArea(
              child: Column(
                children: [
                  MerchantAppBar(titleKey: 'edit_item'),
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF062f6e),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Images Section Card
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context).translate('product_images'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF062f6e),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        _buildImagesSection(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Product Details Card
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context).translate('product_details'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF062f6e),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Form Fields with adjusted styling
                                        TextFormField(
                                          controller: _nameController,
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context).translate('item_name'),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF062f6e)),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return AppLocalizations.of(context).translate('name_required');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Manufacturer Field
                                        TextFormField(
                                          controller: _manufacturerController,
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context).translate('manufacturer'),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF062f6e)),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return AppLocalizations.of(context).translate('manufacturer_required');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Add Category Dropdown
                                        _buildCategoryDropdown(),
                                        const SizedBox(height: 12),

                                        // Add Description Field
                                        TextFormField(
                                          controller: _descriptionController,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context).translate('description'),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF062f6e)),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return AppLocalizations.of(context).translate('description_required');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Quantity Field
                                        TextFormField(
                                          controller: _quantityController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context).translate('quantity'),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF062f6e)),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return AppLocalizations.of(context).translate('quantity_required');
                                            }
                                            if (int.tryParse(value) == null) {
                                              return AppLocalizations.of(context).translate('invalid_quantity');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Add Price Field
                                        TextFormField(
                                          controller: _priceController,
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context).translate('price'),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF062f6e)),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return AppLocalizations.of(context).translate('price_required');
                                            }
                                            if (double.tryParse(value) == null) {
                                              return AppLocalizations.of(context).translate('invalid_price');
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploading ? null : _saveChanges,
                                    icon: _isUploading 
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                    label: Text(
                                      _isUploading
                                          ? '$_uploadProgress%'
                                          : AppLocalizations.of(context).translate('save_changes'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF062f6e),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                      disabledBackgroundColor: Colors.grey[300],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading || _isUploading)
          const LoadingOverlay(),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('category'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF062f6e)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _categories.map((category) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        return DropdownMenuItem<String>(
          value: category['id'],
          child: Text(
            isArabic ? (category['name_ar'] ?? '') : (category['name_en'] ?? ''),
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
          return AppLocalizations.of(context).translate('category_required');
        }
        return null;
      },
    );
  }
}