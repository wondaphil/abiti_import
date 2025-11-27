import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  int? categoryId;

  Uint8List? _photoBytes; // <-- compressed ready-to-save bytes

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = DatabaseHelper.instance;
    final result = await db.getAllCategories();
    setState(() => categories = result);
  }

  // ============================================================================
  // IMAGE PICKER (bottom sheet)
  // ============================================================================
  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // GALLERY PICK (FilePicker)
  // ============================================================================
  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowCompression: false,
      );

      if (result == null) return;

      Uint8List? rawBytes;

      if (result.files.single.bytes != null) {
        rawBytes = result.files.single.bytes;
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        rawBytes = await file.readAsBytes();
      }

      if (rawBytes != null) await _processImage(rawBytes);
    } catch (e) {
      debugPrint("❌ Gallery pick failed: $e");
    }
  }

  // ============================================================================
  // CAMERA PICK (ImagePicker)
  // ============================================================================
  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);

      if (picked == null) return;

      final rawBytes = await picked.readAsBytes();
      await _processImage(rawBytes);
    } catch (e) {
      debugPrint("❌ Camera pick failed: $e");
    }
  }

  // ============================================================================
  // IMAGE PROCESSING (decode → resize → compress)
  // SAME LOGIC as your reference app!
  // ============================================================================
  Future<void> _processImage(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return;

      // Resize max dimension to 500px (maintains aspect ratio)
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 1600 : null,
        height: decoded.height > decoded.width ? 1600 : null,
      );

      // JPEG encode @ quality 80%
      final compressed =
          Uint8List.fromList(img.encodeJpg(resized, quality: 80));

      setState(() => _photoBytes = compressed);
    } catch (e) {
      debugPrint("❌ Image processing failed: $e");
    }
  }

  // ============================================================================
  // SAVE ITEM
  // ============================================================================
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final db = DatabaseHelper.instance;

    await db.insertItem({
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'categoryId': categoryId,
      'photo': _photoBytes, // <-- Nullable BLOB
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (mounted) Navigator.pop(context);
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ---------------- PHOTO PICKER ----------------
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: _photoBytes != null
                      ? Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _photoBytes!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                            // REMOVE BUTTON
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.redAccent),
                              onPressed: () => setState(() => _photoBytes = null),
                            ),
                          ],
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined,
                              size: 40, color: Colors.grey),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- CODE ----------------
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: "Code"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Code required" : null,
              ),
              const SizedBox(height: 16),

              // ---------------- NAME ----------------
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Name required" : null,
              ),
              const SizedBox(height: 16),

              // ---------------- DESCRIPTION ----------------
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: "Description (optional)"),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ---------------- CATEGORY ----------------
              DropdownButtonFormField<int>(
                value: categoryId,
                decoration: const InputDecoration(labelText: "Category"),
                items: [
                  const DropdownMenuItem(value: null, child: Text("None")),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c["id"],
                      child: Text(c["name"]),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
              const SizedBox(height: 28),

              // ---------------- SAVE BUTTON ----------------
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Item"),
                onPressed: _saveItem,
              ),
            ],
          ),
        ),
      ),
    );
  }
}