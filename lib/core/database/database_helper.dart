import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_expense_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../utils/crypto_helper.dart';

class DatabaseHelper {
  static const String _databaseName = 'meratrip.db';
  static const int _databaseVersion = 1;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final isUnderFlutterTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final String path;
    if (isUnderFlutterTest) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE users ADD COLUMN supabase_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN total_actual_cost REAL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN started_at TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN completed_at TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN origin_city TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN origin_timezone TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN destination_city TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN destination_timezone TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN currency_source TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trips ADD COLUMN currency_target TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trip_items ADD COLUMN is_completed INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE trip_items ADD COLUMN completed_at TEXT');
        } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS trip_expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              destination_id INTEGER,
              destination_name TEXT,
              category TEXT NOT NULL,
              amount REAL NOT NULL,
              notes TEXT,
              spent_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
            )
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabel Users (FR-01, FR-02)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supabase_id TEXT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        profile_photo TEXT,
        is_biometric_enabled INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Tabel Destinations (FR-03, FR-07)
    await db.execute('''
      CREATE TABLE destinations (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        elevation_mdpl INTEGER DEFAULT 800,
        ticket_price REAL DEFAULT 0,
        ticket_price_label TEXT,
        opening_hours TEXT,
        estimated_duration TEXT,
        temperature_range TEXT,
        address TEXT NOT NULL,
        image_url TEXT,
        is_saved_offline INTEGER DEFAULT 1,
        rating REAL DEFAULT 4.8,
        review_count INTEGER DEFAULT 100,
        facilities TEXT,
        distance_km REAL DEFAULT 0.0,
        best_visiting_time TEXT
      )
    ''');

    // 3. Tabel Trips (FR-04, FR-05)
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        trip_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        participant_count INTEGER DEFAULT 1,
        target_budget REAL DEFAULT 0,
        total_estimated_cost REAL DEFAULT 0,
        total_actual_cost REAL DEFAULT 0,
        status TEXT DEFAULT 'upcoming',
        reminder_enabled INTEGER DEFAULT 1,
        is_saved_offline INTEGER DEFAULT 1,
        banner_image_url TEXT,
        started_at TEXT,
        completed_at TEXT,
        origin_city TEXT,
        origin_timezone TEXT,
        destination_city TEXT,
        destination_timezone TEXT,
        currency_source TEXT,
        currency_target TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Tabel Trip Items (FR-04)
    await db.execute('''
      CREATE TABLE trip_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        destination_id INTEGER,
        item_name TEXT NOT NULL,
        item_subtitle TEXT,
        visit_order INTEGER NOT NULL,
        planned_time TEXT,
        duration_hours REAL DEFAULT 1.5,
        estimated_cost REAL DEFAULT 0,
        notes TEXT,
        image_url TEXT,
        elevation_mdpl INTEGER DEFAULT 900,
        connecting_distance_km REAL DEFAULT 3.5,
        connecting_time_minutes INTEGER DEFAULT 15,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // 5. Tabel Favorites (FR-03)
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        destination_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, destination_id)
      )
    ''');

    // 6. Tabel Blockchain Blocks (FR-14)
    await db.execute('''
      CREATE TABLE blockchain_blocks (
        block_index INTEGER PRIMARY KEY,
        record_type TEXT NOT NULL,
        reference_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        payload_summary TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        current_hash TEXT NOT NULL,
        is_tampered INTEGER DEFAULT 0
      )
    ''');

    // 7. Tabel Quiz Scores (FR-13)
    await db.execute('''
      CREATE TABLE quiz_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        rank_title TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');

    // 8. Tabel Course Feedback PAM (FR-16)
    await db.execute('''
      CREATE TABLE course_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        student_name TEXT NOT NULL,
        rating INTEGER NOT NULL,
        message TEXT NOT NULL,
        submitted_at TEXT NOT NULL
      )
    ''');

    // 9. Tabel Trip Expenses (Mode Perjalanan Aktif)
    await db.execute('''
      CREATE TABLE trip_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        destination_id INTEGER,
        destination_name TEXT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        spent_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Seed Akun Demo Sesuai Desain Stitch & PRD
    final defaultPasswordHash = CryptoHelper.hashPassword('merapiraya2024');
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'id': 1,
      'name': 'Bima Sakti',
      'email': 'bima.sakti@wisatawan.id',
      'password_hash': defaultPasswordHash,
      'profile_photo': null,
      'is_biometric_enabled': 1,
      'created_at': now,
    });

    // Seed Data Destinasi Wisata Merapi (FR-03, FR-07)
    await _seedDestinations(db);

    // Seed Data Rencana Trip Awal (FR-04, FR-05)
    await _seedTrips(db);
  }

  Future<void> _seedDestinations(Database db) async {
    final batch = db.batch();
    for (final dest in MockDestinations.destinations) {
      batch.insert(
        'destinations',
        dest.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedTrips(Database db) async {
    final now = DateTime.now().toIso8601String();
    // 1. Trip Mendatang: Exploration Offroad Merapi (25 Okt)
    final trip1Id = await db.insert('trips', {
      'id': 1,
      'user_id': 1,
      'trip_name': 'Exploration Offroad Merapi',
      'start_date': '25 Okt 2026',
      'participant_count': 2,
      'target_budget': 500000.0,
      'total_estimated_cost': 40000.0,
      'status': 'upcoming',
      'reminder_enabled': 1,
      'is_saved_offline': 1,
      'banner_image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCwXWD1ehYGmjCp_tx9aHTlZ8jRBa3kBFwla81OgBF70OA_aTU48L3L1uWDxVKLOeOibal32sVtkWDwCjMGF8itjKr-NQN1L86Ee1mYoQwDS-J7cI5ZKVOVXKZ0Xc4FNEYAOodZRXRzOBzJxFqXOJ01UXhwtJqgj6WDkkS3RVXWzd2wa6g9UVa80DlrCKLRbVlgTZnEFnH0cSPkq-wv1H5RkhBThijYlO7htbYniIv84-mxlC7wZ7w',
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Items Trip 1
    final batch = db.batch();
    batch.insert('trip_items', {
      'id': 1,
      'trip_id': trip1Id,
      'destination_id': 2,
      'item_name': 'Museum Sisa Hartaku',
      'item_subtitle': 'Kunjungan Memoar Erupsi',
      'visit_order': 1,
      'planned_time': '07:30 WIB',
      'duration_hours': 1.5,
      'estimated_cost': 20000.0,
      'notes': 'Saksi bisu erupsi Merapi 2010',
      'image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCrMdOhkFyi5cCCa57K_dji1aobrBXghl3FRpJRzpB6sn7bo6utRDLky6lzoF0DEGs94zbs_xZrmfkoF8iEb9n95_6toNdhXzL8CVAwPhteTB6vigjJXWqqiy5Fh9hGiLTrKhMACm4HgA9nMeFkfmS-cmlkoZwsu2PksDLjTIv8_-PI39q2JV4WAcBrrDXgM-b6Eef1b5md8zQyfrkKkaRGG6yn_9VtBJcqzFWJ2Ro0NmgIxXchwCQ',
      'elevation_mdpl': 920,
      'connecting_distance_km': 3.1,
      'connecting_time_minutes': 12,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 2,
      'trip_id': trip1Id,
      'destination_id': 1,
      'item_name': 'Bunker Kaliadem',
      'item_subtitle': 'Spot Panorama Puncak Merapi',
      'visit_order': 2,
      'planned_time': '09:15 WIB',
      'duration_hours': 1.5,
      'estimated_cost': 20000.0,
      'notes': 'Spot panorama kerucut puncak Merapi',
      'image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
      'elevation_mdpl': 1165,
      'connecting_distance_km': 0.0,
      'connecting_time_minutes': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 2. Trip Draft: Trip Kopi & Santai Merapi
    final trip2Id = await db.insert('trips', {
      'id': 2,
      'user_id': 1,
      'trip_name': 'Trip Kopi & Santai Merapi',
      'start_date': 'Kemarin',
      'participant_count': 2,
      'target_budget': 300000.0,
      'total_estimated_cost': 35000.0,
      'status': 'draft',
      'reminder_enabled': 1,
      'is_saved_offline': 1,
      'banner_image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAPCRJJgh8Rcxr67OUIBH0lTkBEjznYjV4dRG5FgHsyOkFAhrLdHE1wBAIXN3blB_0TSNHKVyKtZtLIFFJt8277BtD0ks8ED9PzBx9SXFgFt3jBWChmkm8uOCyZEr-Za1g-7k0Kf6oBpQhN5yO0mPcFO0P9mfeYovAYB9NngDAPmbdPG16QZGbdrhjEWVp_0C0G-8ZWCS0S3UFjvckAn-KVl5TQqS7Yl3ZlBbS98WpVL3OHNQ2Px1Q',
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Draft 2: Sunset Kaliurang & Lava Tour
    await db.insert('trips', {
      'id': 4,
      'user_id': 1,
      'trip_name': 'Sunset Kaliurang & Lava Tour',
      'start_date': '2 hari lalu',
      'participant_count': 2,
      'target_budget': 250000.0,
      'total_estimated_cost': 45000.0,
      'status': 'draft',
      'reminder_enabled': 1,
      'is_saved_offline': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Trip Upcoming 2: Lava Tour Sunrise & Jeep Merapi
    final trip5Id = await db.insert('trips', {
      'id': 5,
      'user_id': 1,
      'trip_name': 'Lava Tour Sunrise & Jeep Merapi',
      'start_date': '28 Okt 2026',
      'origin_city': 'Yogyakarta',
      'destination_city': 'Bunker Kaliadem',
      'participant_count': 3,
      'target_budget': 650000.0,
      'total_estimated_cost': 45000.0,
      'status': 'upcoming',
      'reminder_enabled': 1,
      'is_saved_offline': 1,
      'banner_image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 7,
      'trip_id': trip5Id,
      'destination_id': 1,
      'item_name': 'Bunker Kaliadem',
      'item_subtitle': 'Sunrise Panorama Puncak Merapi',
      'visit_order': 1,
      'planned_time': '05:30 WIB',
      'duration_hours': 2.0,
      'estimated_cost': 25000.0,
      'notes': 'Spot sunrise terbaik lereng selatan',
      'elevation_mdpl': 1165,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 8,
      'trip_id': trip5Id,
      'destination_id': 2,
      'item_name': 'Museum Sisa Hartaku',
      'item_subtitle': 'Edukasi Memoar Erupsi',
      'visit_order': 2,
      'planned_time': '08:00 WIB',
      'duration_hours': 1.5,
      'estimated_cost': 20000.0,
      'notes': 'Koleksi peninggalan erupsi',
      'elevation_mdpl': 920,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 4,
      'trip_id': trip2Id,
      'destination_id': 15,
      'item_name': 'Kopi Klotok & Sawah Pakem',
      'item_subtitle': 'Kuliner Joglo Tradisional',
      'visit_order': 1,
      'planned_time': '15:30 - 17:00',
      'duration_hours': 1.5,
      'estimated_cost': 35000.0,
      'elevation_mdpl': 450,
      'connecting_distance_km': 5.0,
      'connecting_time_minutes': 15,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 3. Trip Selesai: Jelajah Bunker & Lava Tour 2024
    final trip3Id = await db.insert('trips', {
      'id': 3,
      'user_id': 1,
      'trip_name': 'Jelajah Bunker & Lava Tour 2024',
      'start_date': '10 Okt 2024',
      'participant_count': 2,
      'target_budget': 350000.0,
      'total_estimated_cost': 60000.0,
      'total_actual_cost': 320000.0,
      'status': 'completed',
      'completed_at': '2024-10-10 16:30:00',
      'reminder_enabled': 0,
      'is_saved_offline': 1,
      'banner_image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 5,
      'trip_id': trip3Id,
      'destination_id': 1,
      'item_name': 'Bunker Kaliadem',
      'item_subtitle': 'Panorama Puncak & Edukasi Vulkanik',
      'visit_order': 1,
      'planned_time': '08:00 - 10:00',
      'duration_hours': 2.0,
      'estimated_cost': 20000.0,
      'is_completed': 1,
      'completed_at': '2024-10-10 10:00:00',
      'image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
      'elevation_mdpl': 1165,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('trip_items', {
      'id': 6,
      'trip_id': trip3Id,
      'destination_id': 2,
      'item_name': 'Museum Sisa Hartaku',
      'item_subtitle': 'Museum Memori Erupsi 2010',
      'visit_order': 2,
      'planned_time': '10:30 - 12:00',
      'duration_hours': 1.5,
      'estimated_cost': 10000.0,
      'is_completed': 1,
      'completed_at': '2024-10-10 12:00:00',
      'image_url':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCrMdOhkFyi5cCCa57K_dji1aobrBXghl3FRpJRzpB6sn7bo6utRDLky6lzoF0DEGs94zbs_xZrmfkoF8iEb9n95_6toNdhXzL8CVAwPhteTB6vigjJXWqqiy5Fh9hGiLTrKhMACm4HgA9nMeFkfmS-cmlkoZwsu2PksDLjTIv8_-PI39q2JV4WAcBrrDXgM-b6Eef1b5md8zQyfrkKkaRGG6yn_9VtBJcqzFWJ2Ro0NmgIxXchwCQ',
      'elevation_mdpl': 920,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }

  /// Memastikan tabel destinasi telah terisi (berguna bila database sudah ada sebelum seed dibuat)
  Future<void> ensureDestinationsSeeded() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM destinations'),
    );
    if (count == null || count < MockDestinations.destinations.length) {
      await _seedDestinations(db);
    }
  }

  /// Memastikan tabel trips telah terisi
  Future<void> ensureTripsSeeded() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM trips'),
    );
    if (count == null || count == 0) {
      await _seedTrips(db);
    } else {
      final trip5Count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM trips WHERE id = 5'),
      );
      if (trip5Count == null || trip5Count == 0) {
        final now = DateTime.now().toIso8601String();
        await db.insert('trips', {
          'id': 5,
          'user_id': 1,
          'trip_name': 'Lava Tour Sunrise & Jeep Merapi',
          'start_date': '28 Okt 2026',
          'origin_city': 'Yogyakarta',
          'destination_city': 'Bunker Kaliadem',
          'participant_count': 3,
          'target_budget': 650000.0,
          'total_estimated_cost': 45000.0,
          'status': 'upcoming',
          'reminder_enabled': 1,
          'is_saved_offline': 1,
          'banner_image_url':
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final batch = db.batch();
        batch.insert('trip_items', {
          'id': 7,
          'trip_id': 5,
          'destination_id': 1,
          'item_name': 'Bunker Kaliadem',
          'item_subtitle': 'Sunrise Panorama Puncak Merapi',
          'visit_order': 1,
          'planned_time': '05:30 WIB',
          'duration_hours': 2.0,
          'estimated_cost': 25000.0,
          'notes': 'Spot sunrise terbaik lereng selatan',
          'elevation_mdpl': 1165,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        batch.insert('trip_items', {
          'id': 8,
          'trip_id': 5,
          'destination_id': 2,
          'item_name': 'Museum Sisa Hartaku',
          'item_subtitle': 'Edukasi Memoar Erupsi',
          'visit_order': 2,
          'planned_time': '08:00 WIB',
          'duration_hours': 1.5,
          'estimated_cost': 20000.0,
          'notes': 'Koleksi peninggalan erupsi',
          'elevation_mdpl': 920,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await batch.commit(noResult: true);
      }
    }
  }

  /// Menutup koneksi database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ===========================================================================
  // OFFLINE CACHING & SYNC HELPERS (FR-OFFLINE)
  // ===========================================================================

  /// Menyimpan / memperbarui cache destinasi dari Supabase ke SQLite
  Future<void> saveDestinations(List<DestinationModel> destinations) async {
    final db = await database;
    final batch = db.batch();
    for (final dest in destinations) {
      batch.insert(
        'destinations',
        dest.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Mengambil seluruh destinasi dari cache SQLite
  Future<List<DestinationModel>> getCachedDestinations() async {
    final db = await database;
    final results = await db.query('destinations', orderBy: 'id ASC');
    return results.map((map) => DestinationModel.fromMap(map)).toList();
  }

  /// Mengosongkan cache destinasi (misal untuk testing cache kosong)
  Future<void> clearDestinations() async {
    final db = await database;
    await db.delete('destinations');
  }

  /// Menyimpan atau memperbarui cache trip dan trip_items milik user tertentu
  Future<void> saveUserTrips(int userId, List<TripModel> trips) async {
    final db = await database;
    final batch = db.batch();
    for (final trip in trips) {
      final tripMap = trip.toMap();
      tripMap['user_id'] = userId;
      batch.insert(
        'trips',
        tripMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (trip.id != null) {
        batch.delete('trip_items', where: 'trip_id = ?', whereArgs: [trip.id]);
        for (int i = 0; i < trip.items.length; i++) {
          final item = trip.items[i].copyWith(
            tripId: trip.id,
            visitOrder: i + 1,
          );
          final iMap = item.toMap();
          if (item.id == null) {
            iMap.remove('id');
          }
          batch.insert(
            'trip_items',
            iMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
    await batch.commit(noResult: true);
  }

  /// Mengambil daftar trip milik user tertentu dari cache SQLite
  Future<List<TripModel>> getCachedUserTrips(int userId, {String? status}) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (status != null && status.isNotEmpty) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final tripMaps = await db.query(
      'trips',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );

    final List<TripModel> result = [];
    final Set<String> seenTrips = {};
    for (final tMap in tripMaps) {
      final tripId = tMap['id'] as int;
      final tripName = (tMap['trip_name'] as String? ?? '').trim().toLowerCase();
      final tripStatus = tMap['status'] as String? ?? '';
      final dedupKey = '$tripName|$tripStatus';
      if (tripName.isNotEmpty && seenTrips.contains(dedupKey)) {
        continue;
      }
      if (tripName.isNotEmpty) {
        seenTrips.add(dedupKey);
      }

      final itemMaps = await db.query(
        'trip_items',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'visit_order ASC',
      );
      final items = itemMaps.map((iMap) => TripItemModel.fromMap(iMap)).toList();
      result.add(TripModel.fromMap(tMap, items: items));
    }
    return result;
  }

  /// Menghapus semua trip milik user tertentu (misal untuk testing / pemisahan akun)
  Future<void> clearUserTrips(int userId) async {
    final db = await database;
    final userTrips = await db.query(
      'trips',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    for (final row in userTrips) {
      final tripId = row['id'] as int;
      await db.delete('trip_items', where: 'trip_id = ?', whereArgs: [tripId]);
    }
    await db.delete('trips', where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Mengambil ID destinasi favorit milik user tertentu
  Future<Set<int>> getFavoriteIds(int userId) async {
    final db = await database;
    final results = await db.query(
      'favorites',
      columns: ['destination_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.map((row) => row['destination_id'] as int).toSet();
  }

  /// Toggle status favorit destinasi untuk user tertentu
  Future<bool> toggleFavorite(int userId, int destinationId) async {
    final db = await database;
    final existing = await db.query(
      'favorites',
      where: 'user_id = ? AND destination_id = ?',
      whereArgs: [userId, destinationId],
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'favorites',
        where: 'user_id = ? AND destination_id = ?',
        whereArgs: [userId, destinationId],
      );
      return false;
    } else {
      await db.insert('favorites', {
        'user_id': userId,
        'destination_id': destinationId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    }
  }

  // ===========================================================================
  // ACTIVE TRIP & EXPENSES HELPERS
  // ===========================================================================

  /// Memperbarui status trip (upcoming, active, completed)
  Future<void> updateTripStatus(
    int tripId,
    String status, {
    String? startedAt,
    String? completedAt,
    double? totalActualCost,
  }) async {
    final db = await database;
    final Map<String, dynamic> values = {'status': status};
    if (startedAt != null) values['started_at'] = startedAt;
    if (completedAt != null) values['completed_at'] = completedAt;
    if (totalActualCost != null) values['total_actual_cost'] = totalActualCost;
    await db.update('trips', values, where: 'id = ?', whereArgs: [tripId]);
  }

  /// Menandai destinasi dalam trip sudah dikunjungi
  Future<void> markTripItemCompleted(
    int tripId,
    int itemId,
    bool isCompleted, {
    String? completedAt,
  }) async {
    final db = await database;
    await db.update(
      'trip_items',
      {
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt ?? (isCompleted ? DateTime.now().toIso8601String() : null),
      },
      where: 'id = ? AND trip_id = ?',
      whereArgs: [itemId, tripId],
    );
  }

  /// Menyimpan pengeluaran trip baru
  Future<int> saveTripExpense(TripExpenseModel expense) async {
    final db = await database;
    final id = await db.insert(
      'trip_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recalculateTripActualCost(expense.tripId);
    return id;
  }

  /// Mengambil seluruh pengeluaran untuk trip tertentu
  Future<List<TripExpenseModel>> getTripExpenses(int tripId) async {
    final db = await database;
    final maps = await db.query(
      'trip_expenses',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'spent_at DESC',
    );
    return maps.map((m) => TripExpenseModel.fromMap(m)).toList();
  }

  /// Menghapus pengeluaran trip tertentu
  Future<void> deleteTripExpense(int expenseId, int tripId) async {
    final db = await database;
    await db.delete('trip_expenses', where: 'id = ?', whereArgs: [expenseId]);
    await recalculateTripActualCost(tripId);
  }

  /// Menghitung ulang total pengeluaran aktual dan menyimpan ke tabel trips
  Future<double> recalculateTripActualCost(int tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM trip_expenses WHERE trip_id = ?',
      [tripId],
    );
    final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    await db.update(
      'trips',
      {'total_actual_cost': total},
      where: 'id = ?',
      whereArgs: [tripId],
    );
    return total;
  }
}
