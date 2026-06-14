// lib/screens/settings/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/utils/downloads_manager.dart';
import 'package:drift/drift.dart' as drift;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  File? _logo;
  bool _showLetterhead = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = await (db.select(db.companySettings)..where((s) => s.id.equals(1))).getSingleOrNull();
    if (settings != null) {
      _nameController.text = settings.companyName;
      _addressController.text = settings.companyAddress;
      // FIX: Corrected typo from logoPath to logoPath and handled null
      if (settings.logoPath != null) {
        _logo = File(settings.logoPath!);
      }
      _showLetterhead = settings.showLetterhead;
      setState(() {});
    }
  }

  Future<void> _pickLogo() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logo = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<AppDatabase>(context, listen: false);
    final companion = CompanySettingsCompanion(
      id: const drift.Value(1),
      companyName: drift.Value(_nameController.text),
      companyAddress: drift.Value(_addressController.text),
      // FIX: Corrected typo from logoPath to logoPath
      logoPath: _logo != null ? drift.Value(_logo!.path) : const drift.Value.absent(),
      showLetterhead: drift.Value(_showLetterhead),
    );

    await db.into(db.companySettings).insertOnConflictUpdate(companion);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
    }
  }

  Future<void> _cleanUpOldDownloads() async {
    const maxAge = DownloadsManager.defaultMaxAge;
    final ageInDays = maxAge.inDays;
    final manager = DownloadsManager();
    final messenger = ScaffoldMessenger.of(context);

    final summary = await manager.findOldDownloads(maxAge: maxAge);
    if (!mounted) return;

    if (summary.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('No downloads older than $ageInDays days.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete old downloads?'),
        content: Text(
          'This will permanently delete ${summary.count} '
          '${summary.count == 1 ? "file" : "files"} '
          '(${formatBytes(summary.totalBytes)}) older than $ageInDays days '
          'from this app\'s downloads folder. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await manager.deleteOldDownloads(maxAge: maxAge);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Deleted ${result.deletedCount} '
          '${result.deletedCount == 1 ? "file" : "files"} '
          '(${formatBytes(result.freedBytes)} freed).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Company Name'),
              validator: (value) => value!.isEmpty ? 'Please enter your company name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Company Address'),
              maxLines: 3,
              validator: (value) => value!.isEmpty ? 'Please enter your company address' : null,
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Company Logo'),
              subtitle: _logo == null ? const Text('No logo selected') : Text(_logo!.path.split('/').last),
              trailing: const Icon(Icons.image),
              onTap: _pickLogo,
            ),
            if (_logo != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.file(_logo!, height: 100),
              ),
            SwitchListTile(
              title: const Text('Show Letterhead on Invoices'),
              subtitle: const Text('Includes your logo and company details at the top.'),
              value: _showLetterhead,
              onChanged: (bool value) {
                setState(() {
                  _showLetterhead = value;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
            const Divider(height: 48),
            Text('Storage', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Delete old downloads'),
              subtitle: Text(
                'Remove saved invoice files older than '
                '${DownloadsManager.defaultMaxAge.inDays} days.',
              ),
              trailing: const Icon(Icons.delete_sweep_outlined),
              onTap: _cleanUpOldDownloads,
            ),
          ],
        ),
      ),
    );
  }
}