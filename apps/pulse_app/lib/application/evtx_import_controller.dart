import 'package:flutter/foundation.dart';

import '../features/timeline/evtx_import.dart';
import '../logging/app_logger.dart';
import '../platform/evtx_file_reader.dart';

/// Holds an .evtx opened from another PC. While [current] is set the Timeline
/// shows those events instead of this PC's live ones.
class EvtxImportController extends ChangeNotifier {
  EvtxImportController({required this.logger, EvtxFileReader? reader})
      : _reader = reader ?? EvtxFileReader();

  final AppLogger logger;
  final EvtxFileReader _reader;

  EvtxImport? _current;
  bool _loading = false;
  String? _loadingFileName;
  int _generation = 0;

  EvtxImport? get current => _current;
  bool get active => _current != null;
  bool get loading => _loading;
  String? get loadingFileName => _loadingFileName;

  /// Reads [path]; keeps the previous import if this one fails.
  /// Throws [EvtxImportException] with a user-facing message.
  Future<EvtxImport> open(String path) async {
    final generation = ++_generation;
    _loading = true;
    _loadingFileName = path.split(RegExp(r'[\\/]')).last;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    try {
      final imported = await _reader.read(path);
      if (generation != _generation) return imported;
      _current = imported;
      logger.info(
        'EvtxImport',
        'Opened ${imported.fileName}: ${imported.events.length} events '
            'in ${stopwatch.elapsedMilliseconds} ms',
      );
      return imported;
    } on EvtxImportException catch (e) {
      logger.warn('EvtxImport', 'Could not open event log file: ${e.message}');
      rethrow;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _loadingFileName = null;
        notifyListeners();
      }
    }
  }

  /// Back to this PC's live Timeline.
  void close() {
    ++_generation;
    if (_current == null && !_loading) return;
    _current = null;
    _loading = false;
    _loadingFileName = null;
    notifyListeners();
  }
}
