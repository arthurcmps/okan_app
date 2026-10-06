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

  static const schemaVersion = 2;

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
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
      );
    } catch (_) {
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

    // Permite criar um banco v1 nos testes de migração.
    if (version >= 2) {
      await _createSyncSchema(database);
    }
  }

  static Future<void> upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _createSyncSchema(database);

      // Corridas antigas também entram na fila.
      // Não modifica métricas, pontos ou estado das sessões.
      await database.execute('''
        INSERT INTO run_sync_queue (
          owner_uid,
          run_id,
          sync_status,
          created_at_us,
          updated_at_us
        )
        SELECT
          owner_uid,
          run_id,
          'pending',
          updated_at_us,
          updated_at_us
        FROM run_sessions
        WHERE status = 'finished'
      ''');
    }
  }

  static Future<void> _createSyncSchema(Database database) async {
    await database.execute('''
      CREATE TABLE run_sync_queue (
        owner_uid TEXT NOT NULL,
        run_id TEXT NOT NULL,

        sync_status TEXT NOT NULL DEFAULT 'pending'
          CHECK (sync_status IN ('pending', 'failed', 'synced')),

        attempt_count INTEGER NOT NULL DEFAULT 0
          CHECK (attempt_count >= 0),

        next_attempt_at_us INTEGER DEFAULT 0
          CHECK (
            next_attempt_at_us IS NULL
            OR next_attempt_at_us >= 0
          ),

        last_attempt_at_us INTEGER,
        last_error TEXT,
        last_error_code TEXT,

        synced_at_us INTEGER,
        content_hash TEXT,
        server_distance_meters REAL
          CHECK (
            server_distance_meters IS NULL
            OR server_distance_meters >= 0
          ),

        created_at_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL,

        PRIMARY KEY (owner_uid, run_id),

        FOREIGN KEY (owner_uid, run_id)
          REFERENCES run_sessions (owner_uid, run_id)
          ON DELETE CASCADE,

        CHECK (
          sync_status != 'synced'
          OR (
            synced_at_us IS NOT NULL
            AND content_hash IS NOT NULL
            AND server_distance_meters IS NOT NULL
          )
        )
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_run_sync_queue_ready
      ON run_sync_queue (
        owner_uid,
        sync_status,
        next_attempt_at_us,
        created_at_us
      )
    ''');

    // Corrida que já é inserida como finalizada.
    await database.execute('''
      CREATE TRIGGER enqueue_inserted_finished_run
      AFTER INSERT ON run_sessions
      WHEN NEW.status = 'finished'
      BEGIN
        INSERT OR IGNORE INTO run_sync_queue (
          owner_uid,
          run_id,
          sync_status,
          created_at_us,
          updated_at_us
        )
        VALUES (
          NEW.owner_uid,
          NEW.run_id,
          'pending',
          NEW.updated_at_us,
          NEW.updated_at_us
        );
      END
    ''');

    // Corrida ativa que passa para finalizada.
    await database.execute('''
      CREATE TRIGGER enqueue_updated_finished_run
      AFTER UPDATE OF status ON run_sessions
      WHEN NEW.status = 'finished' AND OLD.status != 'finished'
      BEGIN
        INSERT OR IGNORE INTO run_sync_queue (
          owner_uid,
          run_id,
          sync_status,
          created_at_us,
          updated_at_us
        )
        VALUES (
          NEW.owner_uid,
          NEW.run_id,
          'pending',
          NEW.updated_at_us,
          NEW.updated_at_us
        );
      END
    ''');
  }
}
