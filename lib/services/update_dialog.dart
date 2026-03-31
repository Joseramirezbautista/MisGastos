import 'package:flutter/material.dart';
import 'update_service.dart';

class UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.downloadUrl,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva actualización disponible'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Versión ${widget.version} disponible'),
          const SizedBox(height: 8),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Después'),
          ),
        if (!_downloading)
          ElevatedButton(
            onPressed: () async {
              setState(() => _downloading = true);
              await UpdateService.downloadAndInstall(
                widget.downloadUrl,
                    (progress) => setState(() => _progress = progress),
              );
            },
            child: const Text('Actualizar'),
          ),
      ],
    );
  }
}