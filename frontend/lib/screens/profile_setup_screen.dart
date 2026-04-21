import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'classroom_dashboard.dart';
import '../services/api_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String firebaseUid;
  final String email;

  const ProfileSetupScreen({
    super.key,
    required this.firebaseUid,
    required this.email,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  String _selectedRole = 'student';
  String _profileImagePath = '';

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    final String rollNo = _rollNoController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }

    if (_selectedRole == 'student' && rollNo.isEmpty) {
      _showMessage('Please enter your roll number.');
      return;
    }

    if (_selectedRole == 'student' && _profileImagePath.isEmpty) {
      _showMessage('Profile picture is required for students.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.createUserProfile(
        firebaseUid: widget.firebaseUid,
        email: widget.email,
        name: name,
        role: _selectedRole,
        rollNo: _selectedRole == 'student' ? rollNo : '',
        profileImage: _profileImagePath,
      );

      if (!mounted) return;
      _showMessage('Profile saved successfully.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClassroomDashboard(
            firebaseUid: widget.firebaseUid,
            role: _selectedRole,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _profileImagePath = image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 12),
            if (_selectedRole == 'student')
              TextField(
                controller: _rollNoController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _pickImage,
              child: const Text('Upload Profile Picture'),
            ),
            if (_profileImagePath.isNotEmpty)
              Text(
                'Selected: $_profileImagePath',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: const Text('Save Profile'),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
