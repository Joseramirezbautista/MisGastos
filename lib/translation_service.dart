import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Servicio de traducción offline usando ML Kit.
/// Traduce del inglés al español descargando el modelo al dispositivo (~30 MB).
class TranslationService {
  static final TranslationService instance = TranslationService._();
  TranslationService._();

  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();
  bool _modelDescargado = false;

  /// Descarga el modelo inglés→español si aún no está en el dispositivo.
  Future<void> inicializar() async {
    _modelDescargado =
        await _modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode) &&
        await _modelManager.isModelDownloaded(TranslateLanguage.spanish.bcpCode);

    if (!_modelDescargado) {
      await _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
      await _modelManager.downloadModel(TranslateLanguage.spanish.bcpCode);
      _modelDescargado = true;
    }

    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.spanish,
    );
  }

  /// Traduce un texto del inglés al español.
  /// Llama a [inicializar()] antes de usar este método.
  Future<String> traducir(String texto) async {
    if (_translator == null) await inicializar();
    return await _translator!.translateText(texto);
  }

  /// Libera recursos del traductor.
  void cerrar() {
    _translator?.close();
    _translator = null;
  }
}
