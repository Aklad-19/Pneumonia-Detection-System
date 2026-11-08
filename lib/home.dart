import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import login page (for logout navigation)
import 'login.dart';

//for loading image and Tfmodel
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'checkout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Logs out the user from Firebase and navigates back to the Login page
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been logged out.')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  /// Navigates to the checkout (SSLCommerz) page for donation
  Future<void> _goToDonation() async {
    // Go to Checkout screen and wait for payment result
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const Checkout()),
    );

    // Avoid using BuildContext if widget is disposed
    if (!mounted) return;

    // If payment succeeded (returned true from payment_helper.dart)
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Thank you for your donation!'),
        ),
      );
    }
  }
  /*
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pneumonia Detection'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hello, ${user?.email ?? "User"} 👋',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // 🌟 Donation button
            ElevatedButton.icon(
              onPressed: _goToDonation,
              icon: const Icon(Icons.volunteer_activism, color: Colors.white),
              label: const Text(
                'Donation',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout button (duplicate from AppBar)
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }*/
  //ML and image state
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;
  String? _prediction;
  bool _busy = false;
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }
  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
  bool _modelLoaded = false;

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/pneumonia.tflite');
      _modelLoaded = true;
      debugPrint('Model loaded successfully');

    } catch (e) {
      debugPrint('Error loading model: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load ML model')),
      );
    }
  }
  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }


  Future<void> _pickFromGallery() async {
    // For Android: let image_picker use the system picker (no storage permission requested)
    // For iOS: request photos permission
    bool granted = true;
    if (!Platform.isAndroid) {
      granted = await _requestPermission(Permission.photos);
    }

    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied')),
      );
      return;
    }

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _imagePath = picked.path;
        _prediction = null;
      });
    }
  }


  Future<void> _captureFromCamera() async {
    final granted = await _requestPermission(Permission.camera);
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
      return;
    }

    final XFile? captured = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (captured != null) {
      setState(() {
        _imagePath = captured.path;
        _prediction = null;
      });
    }
  }

  Future<void> _uploadToFirebase() async {
    if (_imagePath == null) return;
    setState(() => _busy = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final file = File(_imagePath!);
      final fileName =
          'xray_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('xray_images')
          .child(fileName);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('xray_uploads').add({
        'userId': user.uid,
        'imageUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runPrediction() async {
    if (!_modelLoaded || _interpreter == null || _imagePath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model or image not ready')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _prediction = null;
    });

    try {
      final bytes = await File(_imagePath!).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Invalid image');

      const int inputSize = 256; // adjust to  model
      final resized = img.copyResize(
        original,
        width: inputSize,
        height: inputSize,
      );

      final input = List.generate(
        1,
            (_) => List.generate(
          inputSize,
              (y) => List.generate(
            inputSize,
                (x) {
              final pixel = resized.getPixel(x, y);
              final r = pixel.r/256.0;
              final g = pixel.g/256.0;
              final b = pixel.b/256.0;
              return [r, g, b];
            },
          ),
        ),
      );
      final output = List.filled(2, 0.0).reshape([1, 2]);
      _interpreter!.run(input, output);

      final pneumoniaScore = output[0][1];
      final normalScore = output[0][0];

      setState(() {
        _prediction = pneumoniaScore > normalScore
            ? 'Pneumonia detected (score: ${pneumoniaScore.toStringAsFixed(3)})'
            : 'Normal (score: ${normalScore.toStringAsFixed(3)})';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prediction failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Pneumonia Detection'),
          backgroundColor: Colors.blueAccent,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(
                'Hello, ${user?.email ?? "User"} 👋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                // X-ray preview
                Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    child: _imagePath == null
                        ? const Center(
                      child: Text(
                        'No X-ray selected',
                        textAlign: TextAlign.center,
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                ),


                const SizedBox(height: 16),

                // Gallery and Camera buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _captureFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Upload and Detect buttons
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              ElevatedButton.icon(
              onPressed:
              (_busy || _imagePath == null) ? null : _uploadToFirebase,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                      (_busy || _imagePath == null) ? null : _runPrediction,
                      icon: const Icon(Icons.medical_services),
                      label: const Text('Detect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ],
              ),
                const SizedBox(height: 16),

                if (_busy) const CircularProgressIndicator(),
        if (_prediction != null && !_busy) ...[
    const SizedBox(height: 8),
    Text(
    'Result: $_prediction',
    style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    ],
    const SizedBox(height: 32),

    // Donation button (kept)
    ElevatedButton.icon(
    onPressed: _goToDonation,
    icon:
    const Icon(Icons.volunteer_activism, color: Colors.white),
    label: const Text(
    'Donation',
    style: TextStyle(fontSize: 18, color: Colors.white),
    ),
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blueAccent,
    padding: const EdgeInsets.symmetric(
    horizontal: 40, vertical: 15),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    ),


    const SizedBox(height: 24),

    // Logout button (kept)
    ElevatedButton.icon(
    onPressed: _logout,
    icon: const Icon(Icons.logout),
    label: const Text('Logout'),
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.redAccent,
    padding: const EdgeInsets.symmetric(
    horizontal: 40, vertical: 15),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    ),
    ),
                  ],
                ),
            ),
        ),
    );
  }

}
