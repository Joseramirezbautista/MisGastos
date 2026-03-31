import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class UpdateService {
  static const String _user = 'Joseramirezbautista';
  static const String _repo = 'MisGastos';
  static const String _apiUrl =
      'https://api.github.com/repos/$_user/$_repo/releases/latest';

  // Verifica si hay actualización disponible
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.parse(info.buildNumber); // 4

      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final tagName = data['tag_name'] as String; // ej: "1.0.0+5"
      final remoteBuild = int.parse(tagName.split('+').last);

      if (remoteBuild > currentBuild) {
        // Busca el APK en los assets del release
        final assets = data['assets'] as List;
        final apkAsset = assets.firstWhere(
              (a) => (a['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset != null) {
          return {
            'version': tagName,
            'download_url': apkAsset['browser_download_url'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Descarga e instala el APK
  static Future<void> downloadAndInstall(
      String url,
      Function(double) onProgress,
      ) async {
    // Pedir permisos
    await Permission.requestInstallPackages.request();

    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/update.apk';
    final file = File(filePath);

    // Descargar con progreso
    final response = await http.Client().send(
      http.Request('GET', Uri.parse(url)),
    );

    final total = response.contentLength ?? 1;
    int downloaded = 0;
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      sink.add(chunk);
      downloaded += chunk.length;
      onProgress(downloaded / total);
    }).asFuture();

    await sink.close();

    // Instalar
    await OpenFilex.open(filePath);
  }
}