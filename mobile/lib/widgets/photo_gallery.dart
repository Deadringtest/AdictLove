import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.photoPaths, this.size = 280});

  final List<String> photoPaths;
  final double size;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _api = ApiService();
  int _page = 0;
  late final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoPaths.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person, size: 64),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photoPaths.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => Image.network(
                _api.photoUrl(widget.photoPaths[i])!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (widget.photoPaths.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.photoPaths.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? Colors.white : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
