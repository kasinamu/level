import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/reference_point.dart';
import '../services/reference_point_service.dart';

class ReferencePointsScreen extends StatefulWidget {
  final ReferencePointService service;

  const ReferencePointsScreen({super.key, required this.service});

  @override
  State<ReferencePointsScreen> createState() => _ReferencePointsScreenState();
}

class _ReferencePointsScreenState extends State<ReferencePointsScreen> {
  final ImagePicker _picker = ImagePicker();

  List<ReferencePoint> _points = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _loading = true);
    final points = await widget.service.fetchPoints();
    if (!mounted) return;
    setState(() {
      _points = points;
      _loading = false;
    });
  }

  Future<void> _addPoint() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) return;

      final name = await _askForName(image.path);
      if (!mounted) return;
      final trimmed = name?.trim() ?? '';
      if (trimmed.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('기준점 이름을 입력해 주세요.')));
        return;
      }

      setState(() => _saving = true);
      final point = await widget.service.addPoint(
        name: trimmed,
        photoSource: File(image.path),
      );

      if (!mounted) return;
      setState(() {
        _points.insert(0, point);
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('기준점이 저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<String?> _askForName(String photoPath) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기준점 이름 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(photoPath),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '현장 이름 또는 번호',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _deletePoint(ReferencePoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('\'${point.name}\' 기준점을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.service.deletePoint(point);
      if (!mounted) return;
      setState(() {
        _points.removeWhere((p) => p.id == point.id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 문제가 발생했습니다: $e')),
      );
    }
  }

  void _showPhoto(ReferencePoint point) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: InteractiveViewer(
                  child: Image.file(
                    File(point.photoPath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(point.createdAt),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_points.isEmpty) {
      return const Center(
        child: Text(
          '저장된 기준점이 없습니다.\n하단 카메라 버튼을 눌러 기록을 시작해 보세요.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _points.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final point = _points[index];
          final file = File(point.photoPath);
          return GestureDetector(
            onTap: () => _showPhoto(point),
            child: Card(
              elevation: 1,
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                  ),
                ),
                title: Text(point.name),
                subtitle: Text(_formatDate(point.createdAt)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deletePoint(point),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기준점 기록'),
      ),
      body: _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addPoint,
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.camera_alt),
        label: Text(_saving ? '저장 중...' : '기준점 촬영'),
      ),
    );
  }
}
