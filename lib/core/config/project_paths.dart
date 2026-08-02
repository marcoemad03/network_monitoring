import 'dart:io';

/// Resolves project-root-relative paths for backend auto-start on desktop.
class ProjectPaths {
  static String? _projectRoot;

  static String get projectRoot {
    _projectRoot ??= _findProjectRoot();
    return _projectRoot!;
  }

  static String resolve(String relativePath) {
    final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
    return '${projectRoot}${Platform.pathSeparator}$normalized';
  }

  static String? _findProjectRoot() {
    for (final startPath in _candidateStartPaths()) {
      final root = _walkUpForPubspec(startPath);
      if (root != null) {
        return root;
      }
    }
    return Directory.current.path;
  }

  static Iterable<String> _candidateStartPaths() sync* {
    yield Directory.current.path;
    yield File(Platform.resolvedExecutable).parent.path;
  }

  static String? _walkUpForPubspec(String startPath) {
    var dir = Directory(startPath);
    while (true) {
      if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        return null;
      }
      dir = parent;
    }
  }
}
