// Stub для sqflite на веб-платформе
// Этот файл используется только для веб-сборки, чтобы исключить sqflite из бандла

/// Stub класс Database для веб
class Database {
  Database._();
  
  // Stub методы для совместимости с кодом
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
  
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
  
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
  
  Future<int> update(String table, Map<String, Object?> values, {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
  
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
  
  Future<void> close() async {
    throw UnsupportedError('SQLite не поддерживается на веб-платформе');
  }
}

/// Stub enum для ConflictAlgorithm
enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

/// Stub функция для получения пути к базе данных
Future<String> getDatabasesPath() async {
  throw UnsupportedError('SQLite не поддерживается на веб-платформе');
}

/// Stub функция для открытия базы данных
Future<Database> openDatabase(
  String path, {
  int? version,
  Function(Database, int)? onCreate,
  Function(Database, int, int)? onUpgrade,
}) async {
  throw UnsupportedError('SQLite не поддерживается на веб-платформе');
}

