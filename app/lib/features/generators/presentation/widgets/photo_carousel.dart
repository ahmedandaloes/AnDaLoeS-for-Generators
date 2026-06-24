import 'package:flutter/material.dart';

class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({super.key, required this.photos});
  final List<String> photos;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _current = 0;

  void _openGallery(BuildContext context, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) =>
          FullScreenGallery(photos: widget.photos, initialIndex: index),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () => _openGallery(ctx, i),
            child: Image.network(
              widget.photos[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.bolt, size: 64),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.zoom_in, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '${widget.photos.length} photo${widget.photos.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ]),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  const FullScreenGallery(
      {super.key, required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery>
    with SingleTickerProviderStateMixin {
  late final PageController _ctrl;
  late final PageController _thumbCtrl;
  late final AnimationController _dismissCtrl;
  late int _current;

  double _dragY = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
    _thumbCtrl = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.18,
    );
    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _thumbCtrl.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
    if (_thumbCtrl.hasClients) {
      _thumbCtrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragY += d.delta.dy;
      _isDragging = true;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_dragY.abs() > 100 || velocity.abs() > 600) {
      Navigator.pop(context);
    } else {
      setState(() {
        _dragY = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dismissFraction = (_dragY.abs() / 300).clamp(0.0, 1.0);
    final bgOpacity = (1 - dismissFraction * 0.8).clamp(0.2, 1.0);
    final scale = (1 - dismissFraction * 0.15).clamp(0.8, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            // Main photo view
            Transform.translate(
              offset: Offset(0, _dragY),
              child: Transform.scale(
                scale: scale,
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: widget.photos.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        widget.photos[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top bar
            AnimatedOpacity(
              opacity: _isDragging ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.black38),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (widget.photos.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_current + 1} / ${widget.photos.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                  ]),
                ),
              ),
            ),

            // Thumbnail strip at bottom
            if (widget.photos.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    height: 72,
                    child: PageView.builder(
                      controller: _thumbCtrl,
                      itemCount: widget.photos.length,
                      onPageChanged: (i) {
                        setState(() => _current = i);
                        _ctrl.animateToPage(i,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut);
                      },
                      itemBuilder: (_, i) {
                        final isSelected = i == _current;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _current = i);
                            _ctrl.animateToPage(i,
                                duration:
                                    const Duration(milliseconds: 250),
                                curve: Curves.easeOut);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Opacity(
                                opacity: isSelected ? 1.0 : 0.5,
                                child: Image.network(
                                  widget.photos[i],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Swipe hint
            if (_isDragging)
              const Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Release to close',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
