import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../providers/post_provider.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLocating = false;
  Position? _currentPosition;
  String? _address; // In a real app, use geocoding to get address string

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      // Check permissions
      var status = await Permission.location.request();
      if (status.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _currentPosition = position;
          _address = "Location attached"; // Placeholder
        });
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Location permission denied')),
           );
         }
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please enter some content or add an image')),
       );
       return;
    }

    final provider = context.read<PostProvider>();
    List<String> uploadedImageUrls = [];

    // 1. Upload Images
    if (_selectedImages.isNotEmpty) {
      for (var imageFile in _selectedImages) {
        final url = await provider.uploadImageToOSS(imageFile);
        if (url != null) {
          uploadedImageUrls.add(url);
        } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Failed to upload image')),
             );
           }
           return;
        }
      }
    }

    // 2. Create Post
    final success = await provider.createPost(
      content: content,
      images: uploadedImageUrls,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      address: _address,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully!')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish post')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          Consumer<PostProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.isLoading || provider.isUploading
                    ? null
                    : _submitPost,
                child: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ],
      ),
      body: Consumer<PostProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              Column(
                children: [
                  if (provider.isUploading)
                     LinearProgressIndicator(
                       value: double.tryParse(provider.uploadProgress.replaceAll('%', ''))! / 100,
                       backgroundColor: Colors.grey[800],
                       valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                     ),
                  
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _contentController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: "What's on your mind?",
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Image Grid
                        if (_selectedImages.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _selectedImages.length + 1, // +1 for add button
                            itemBuilder: (context, index) {
                              if (index == _selectedImages.length) {
                                return _buildAddImageButton();
                              }
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        else
                           Align(
                             alignment: Alignment.centerLeft,
                             child: _buildAddImageButton(isLarge: true),
                           ),
                      ],
                    ),
                  ),
                  
                  // Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                         IconButton(
                           icon: Icon(Icons.image, color: Theme.of(context).primaryColor),
                           onPressed: _pickImage,
                         ),
                         IconButton(
                           icon: Icon(
                             _currentPosition != null ? Icons.location_on : Icons.location_on_outlined,
                             color: _currentPosition != null ? Theme.of(context).primaryColor : Colors.grey,
                           ),
                           onPressed: _getLocation,
                         ),
                         if (_isLocating)
                           const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                         if (_currentPosition != null)
                            Expanded(
                              child: Text(
                                _address ?? 'Location set',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
              if (provider.isLoading && !provider.isUploading)
                 Container(
                   color: Colors.black45,
                   child: const Center(child: CircularProgressIndicator()),
                 ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddImageButton({bool isLarge = false}) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: isLarge ? 100 : null,
        height: isLarge ? 100 : null,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add, color: Colors.grey[400]),
      ),
    );
  }
}
