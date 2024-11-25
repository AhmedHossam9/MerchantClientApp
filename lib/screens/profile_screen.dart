import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/client_app_bar.dart';
import '../widgets/animated_nav_bar.dart';
import '../widgets/loading_overlay.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  const ProfileScreen({
    Key? key,
    required this.setLocale,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  String? _profileImageUrl;
  bool _isEditing = false;
  late drive.DriveApi _driveApi;
  String? _appFolderId;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadUserData();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeDriveApi() async {
    // Load the JSON file
    final jsonString = await rootBundle.loadString('assets/credentials/cobalt-ion-442107-b8-f8666a191395.json');
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    
    final client = await clientViaServiceAccount(credentials, [drive.DriveApi.driveFileScope]);
    _driveApi = drive.DriveApi(client);

    // Check if app folder exists
    final folderList = await _driveApi.files.list(
      q: "name='StorageTestApp' and mimeType='application/vnd.google-apps.folder'",
    );

    if (folderList.files?.isEmpty ?? true) {
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
    } else {
      _appFolderId = folderList.files!.first.id;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists) {
          setState(() {
            _emailController.text = user.email ?? '';
            _usernameController.text = userData.data()?['username'] ?? '';
            _phoneController.text = userData.data()?['phone_number'] ?? '';
            _addressController.text = userData.data()?['address'] ?? '';
            _profileImageUrl = userData.data()?['profileImage'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() => _isLoading = true);
        
        final user = FirebaseAuth.instance.currentUser;
        final fileName = '${user!.uid}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Create Drive file metadata
        var driveFile = drive.File()
          ..name = fileName
          ..parents = [_appFolderId!]
          ..mimeType = 'image/jpeg';

        // Upload file
        final bytes = await image.readAsBytes();
        final media = drive.Media(Stream.value(bytes), bytes.length);
        
        // Delete existing profile image
        if (_profileImageUrl != null) {
          try {
            final fileId = _extractFileIdFromUrl(_profileImageUrl!);
            if (fileId != null) {
              await _driveApi.files.delete(fileId);
            }
          } catch (e) {
            print('Error deleting old profile image: $e');
          }
        }

        final uploadedFile = await _driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );

        await _driveApi.permissions.create(
          drive.Permission()
            ..type = 'anyone'
            ..role = 'reader',
          uploadedFile.id!,
        );

        // Use direct CDN URL format
        final imageUrl = 'https://drive.google.com/uc?export=view&id=${uploadedFile.id}';

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImage': imageUrl});

        setState(() {
          _profileImageUrl = imageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('error_uploading_image');
    }
  }

  String? _extractFileIdFromUrl(String url) {
    try {
      if (url.contains('drive.google.com')) {
        final regex = RegExp(r'id=([^&]+)');
        final match = regex.firstMatch(url);
        return match?.group(1);
      } else if (url.contains('lh3.googleusercontent.com')) {
        final parts = url.split('/');
        return parts[parts.length - 1];
      }
      return null;
    } catch (e) {
      print('Error extracting file ID: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
      });

      setState(() => _isEditing = false);
      _showSuccessSnackBar('profile_updated_success');
    } catch (e) {
      print('Error updating profile: $e');
      _showErrorSnackBar('error_updating_profile');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String messageKey) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate(messageKey)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String messageKey) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate(messageKey)),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
          appBar: AppBar(
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/efinance.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).translate('profile'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.logout, 
                color: isDarkMode ? Colors.white : const Color(0xFFe2211c)
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
              },
            ),
            actions: [
              // Theme Toggle Button
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return RotationTransition(
                      turns: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(isDarkMode),
                    color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                  ),
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
              ),
              // Language Selector
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'en') {
                    widget.setLocale(const Locale('en'));
                  } else if (value == 'ar') {
                    widget.setLocale(const Locale('ar'));
                  }
                },
                icon: Icon(
                  Icons.language,
                  color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        Icon(Icons.language, 
                          size: 20,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'English',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ar',
                    child: Row(
                      children: [
                        Icon(Icons.language, 
                          size: 20,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'العربية',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFe2211c),
                                width: 2,
                              ),
                              color: Colors.grey[100],
                              image: _profileImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_profileImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImageUrl == null
                                ? Icon(Icons.person_outline, 
                                    size: 60, 
                                    color: const Color(0xFFe2211c))
                                : null,
                          ),
                          const SizedBox(height: 24),

                          // User Info Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkMode 
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _emailController,
                                  labelKey: 'email',
                                  icon: Icons.email_rounded,
                                  enabled: _isEditing,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _usernameController,
                                  labelKey: 'username',
                                  icon: Icons.person_rounded,
                                  enabled: _isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _phoneController,
                                  labelKey: 'phone_number',
                                  icon: Icons.phone_rounded,
                                  enabled: _isEditing,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _addressController,
                                  labelKey: 'address',
                                  icon: Icons.location_on_rounded,
                                  enabled: _isEditing,
                                  maxLines: 2,
                                ),
                                if (_isEditing) ...[
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    labelKey: 'new_password',
                                    icon: Icons.lock_rounded,
                                    enabled: true,
                                    isPassword: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isEditing)
                                ElevatedButton.icon(
                                  onPressed: () => setState(() => _isEditing = true),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: Text(
                                    AppLocalizations.of(context).translate('edit_profile'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF062f6e),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              else ...[
                                ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save_rounded),
                                  label: Text(
                                    AppLocalizations.of(context).translate('save'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () => setState(() => _isEditing = false),
                                  icon: const Icon(Icons.close_rounded),
                                  label: Text(
                                    AppLocalizations.of(context).translate('cancel'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedNavBar(
                  selectedIndex: 5,
                  onItemSelected: (index) {
                    if (index == 5) return;
                    String route;
                    switch (index) {
                      case 0:
                        route = '/services_home_page';
                        break;
                      case 1:
                        route = '/browse';
                        break;
                      case 2:
                        route = '/favorites';
                        break;
                      case 3:
                        route = '/chat';
                        break;
                      case 4:
                        route = '/cart';
                        break;
                      default:
                        return;
                    }
                    Navigator.pushReplacementNamed(context, route);
                  },
                ),
              ],
            ),
          ),
        ),
        if (_isLoading) const LoadingOverlay(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelKey,
    required IconData icon,
    bool enabled = true,
    bool isPassword = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: isDarkMode 
            ? Colors.white 
            : const Color(0xFF062f6e),
        fontSize: 16.0,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(labelKey),
        labelStyle: TextStyle(
          color: enabled 
              ? (isDarkMode ? Colors.white : const Color(0xFF062f6e))
              : Colors.grey,
          fontSize: 14.0,
        ),
        prefixIcon: Icon(
          icon, 
          color: enabled 
              ? (isDarkMode ? Colors.white : const Color(0xFF062f6e))
              : Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white70 : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 2.0,
          ),
        ),
        filled: true,
        fillColor: isDarkMode 
            ? const Color(0xFF1E1E1E)
            : (enabled ? Colors.white : Colors.grey[100]),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('field_required');
        }
        return null;
      },
    );
  }
}