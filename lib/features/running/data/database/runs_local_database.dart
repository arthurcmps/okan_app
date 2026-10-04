import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class RunsLocalDatabase {
  RunsLocalDatabase({required this.environment}) {
    if (!{'dev', 'staging', 'prod'}.contains(environment)) {
      throw ArgumentError.value(
        environment,
        'environment',
        'Use dev, staging ou prod.',
      );
    }
  }

  final String environment;

  Future<Database>? _opening;

  Future<Database> open() {
    return _opening ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    try {
      final directory = await getDatabasesPath();

      final databasePath = path.join(directory, 'okan_running_$environment.db');

      return await openDatabase(
        databasePath,
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: createSchema,
      );
    } catch (_) {
      // Permite tentar abrir novamente após uma falha.
      _opening = null;
      rethrow;
    }
  }

  static Future<void> createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE run_sessions (
        owner_uid TEXT NOT NULL,
        run_id TEXT NOT NULL,
        started_at_us INTEGER NOT NULL,
        ended_at_us INTEGER,
        status TEXT NOT NULL
          CHECK (status IN ('recording', 'paused', 'finished')),
        active_duration_us INTEGER NOT NULL
          CHECK (active_duration_us >= 0),
        distance_meters REAL NOT NULL
          CHECK (distance_meters >= 0),
        point_count INTEGER NOT NULL
          CHECK (point_count >= 0),
        updated_at_us INTEGER NOT NULL,

        PRIMARY KEY (owner_uid, run_id),

        CHECK (
          (status = 'finished' AND ended_at_us IS NOT NULL)
          OR
          (status IN ('recording', 'paused') AND ended_at_us IS NULL)
        )
      )
    ''');

    await database.execute('''
      CREATE TABLE run_points (
        owner_uid TEXT NOT NULL,
        run_id TEXT NOT NULL,
        sequence INTEGER NOT NULL
          CHECK (sequence >= 0),
        segment_index INTEGER NOT NULL
          CHECK (segment_index >= 0),
        latitude REAL NOT NULL
          CHECK (latitude BETWEEN -90 AND 90),
        longitude REAL NOT NULL
          CHECK (longitude BETWEEN -180 AND 180),
        recorded_at_us INTEGER NOT NULL,
        accuracy_meters REAL NOT NULL
          CHECK (accuracy_meters >= 0),

        PRIMARY KEY (owner_uid, run_id, sequence),

        FOREIGN KEY (owner_uid, run_id)
          REFERENCES run_sessions (owner_uid, run_id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_run_sessions_history
      ON run_sessions (owner_uid, status, started_at_us DESC, run_id)
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX idx_run_sessions_one_active
      ON run_sessions (owner_uid)
      WHERE status IN ('recording', 'paused')
    ''');
  }
}
