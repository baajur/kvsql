import 'dart:async';
import 'package:pedantic/pedantic.dart';
import 'package:sqlcool/sqlcool.dart';
import 'serializers.dart';
import 'schema.dart';

/// The key/value store
class KvStore {
  /// If an existing [Db] is provided it has to be initialized
  /// with the [kvSchema] before using. If no [Db] is provided
  /// the store wil use it's own database
  KvStore(
      {this.db,
      this.inMemory = false,
      this.path = "kvstore.db",
      this.verbose = false}) {
    if (db != null) {
      assert(db.schema != null);
      if (this.db.schema.table("kvstore") == null) {
        throw (ArgumentError("The kvstore table schema does not exist. " +
            "Please initialize your database with the kvSchema like this:\n" +
            'db.init(path: "dbname.db", schema: [kvSchema()])'));
      }
    }
    _init();
  }

  /// The Sqlcool [Db] to use
  Db db;

  /// The location of the db file, relative
  /// to the documents directory. Used if no database is provided
  final String path;

  /// Verbosity
  final bool verbose;

  /// Use an in memory copy of the store
  ///
  /// Required to use [selectSync]
  final bool inMemory;

  final Completer _readyCompleter = Completer<Null>();
  Db _db;
  final _changefeed = StreamController<List<dynamic>>.broadcast();
  Map<String, dynamic> _inMemoryStore;

  /// The ready callback
  Future get onReady => _readyCompleter.future;

  /// Initialize the database
  Future<void> _init() async {
    /// [path] is the location of the database file, relative
    /// to the documents directory
    if (db == null) {
      _db = Db();
      db = _db;
      await _db.init(path: path, schema: [kvSchema()], verbose: verbose);
    } else {
      _db = db;
    }

    /// Initialize the in memory store if needed
    if (inMemory) {
      await _db.onReady;
      _inMemoryStore = <String, dynamic>{};
      final List<Map<String, dynamic>> res = await _db.select(table: "kvstore");
      res.forEach((Map<String, dynamic> item) =>
          _inMemoryStore[item["key"].toString()] = decodeFromTypeStr<dynamic>(
              item["value"], item["type"].toString()));
    }

    /// Run the queue for the [push] method
    unawaited(_runQueue());
    _readyCompleter.complete();
  }

  /// Insert a key/value pair into the database
  ///
  /// Returns the id of the new inserted database row
  Future<int> insert<T>(String key, T value) async {
    if (!(value == dynamic)) {
      throw ArgumentError("Please provide a non dynamic type");
    }
    int id;
    if (inMemory == true) _inMemoryStore[key] = value;
    final List<String> res = encode(value);
    final String val = res[0] ?? "NULL";
    final String typeStr = res[1];
    try {
      final Map<String, String> row = <String, String>{
        "key": key,
        "value": val,
        "type": typeStr
      };
      id = await _db.insert(table: "kvstore", row: row, verbose: verbose);
    } catch (e) {
      throw ("Can not insert data $e");
    }
    return id;
  }

  /// Delete a key from the database
  ///
  /// Returns the number of deleted items
  Future<void> delete(String key) async {
    int deleted = 0;
    try {
      deleted = await _db.delete(
          table: "kvstore", where: 'key="$key"', verbose: verbose);
      if (inMemory == true) _inMemoryStore.remove(key);
    } catch (e) {
      throw ("Can not delete data $e");
    }
    return deleted;
  }

  /// Update a key to a new value
  ///
  /// Return true if the key has been updated
  Future<bool> update<T>(String key, T value) async {
    if (!(value is T)) {
      throw ArgumentError(
          "The value is of type ${value.runtimeType} and should be $T");
    }
    int updated = 0;
    try {
      if (inMemory == true) _inMemoryStore[key] = value;
      final List<String> res = encode(value);
      final String val = res[0] ?? "NULL";
      final String typeStr = res[1];
      final Map<String, String> row = <String, String>{
        "value": val,
        "type": typeStr
      };
      updated = await _db.update(
          table: "kvstore", where: 'key="$key"', row: row, verbose: verbose);
    } catch (e) {
      throw ("Can not update data $e");
    }
    bool ok = false;
    if (updated == 1) ok = true;
    return ok;
  }

  /// Get a map value from a key
  ///
  /// <K> is the map key type and <V> is the map value type
  Future<Map<K, V>> selectMap<K, V>(String key) async {
    final res = await _selectQuery(key);
    if (res == null) {
      return null;
    }
    final Map<K, V> result = decodeMap<K, V>(res["value"]);
    return result;
  }

  /// Get a list value from a key
  ///
  /// <T> is the list content type
  Future<List<T>> selectList<T>(String key) async {
    final res = await _selectQuery(key);
    if (res == null) {
      return null;
    }
    final List<T> result = decodeList<T>(res["value"]);
    return result;
  }

  /// Get a value from a key
  Future<T> select<T>(String key) async {
    return _select<T>(key);
  }

  /// Get a value from a key
  Future selectDynamic(String key) async {
    return _select<dynamic>(key, untyped: true);
  }

  Future<T> _select<T>(String key, {bool untyped = false}) async {
    if (!untyped) {
      if (T == dynamic) {
        throw (ArgumentError("Please provide a non dynamic type"));
      }
    }
    if (T is Map) {
      throw (ArgumentError("Please use selectMap<K, V> for maps data type"));
    } else if (T is List) {
      throw (ArgumentError("Please use selectList<T> for lists data type"));
    }
    final res = await _selectQuery(key);
    T value;
    try {
      if (res != null) {
        dynamic val = res["value"];
        if (val.toString() == "NULL") val = null;
        if (!untyped) {
          final String type = res[0]["type"].toString();
          value = decodeFromTypeStr<T>(val, type);
        } else {
          value = val as T;
        }
      } else {
        return null;
      }
    } catch (e) {
      throw ("Can not decode data from $res : $e");
    }
    if (T != dynamic) {
      if (!(value is T)) {
        throw ("Value is of type ${value.runtimeType} and should be $T");
      }
    }
    return value;
  }

  Future<Map<String, dynamic>> _selectQuery(String key) async {
    Map<String, dynamic> res;
    try {
      final qres = await _db.select(
          table: "kvstore",
          columns: "key,value,type",
          where: 'key="$key"',
          verbose: verbose);
      if (qres.isEmpty) {
        return null;
      }
      res = qres[0];
    } catch (e) {
      throw ("Can not select data $e");
    }
    return res;
  }

  /// Insert a key or update it if not present
  Future<void> upsert<T>(String key, T value) async {
    if (!(value is T)) {
      throw (ArgumentError(
          "The value is of type ${value.runtimeType} and should be $T"));
    }
    try {
      if (inMemory == true) _inMemoryStore[key] = value;
      List<String> encoded;
      try {
        encoded = encode(value);
      } catch (e) {
        throw ("Encding $value failed: $e");
      }
      final String val = encoded[0] ?? "NULL";
      final String typeStr = encoded[1];
      final Map<String, String> row = <String, String>{
        "key": key,
        "value": val,
        "type": typeStr
      };
      await _db
          .upsert(table: "kvstore", row: row, verbose: verbose)
          .catchError((dynamic e) {
        throw ("Can not update store $e");
      });
    } catch (e) {
      throw ("Can not upsert data $e");
    }
  }

  /// Change the value of a key if it exists or insert it otherwise
  ///
  /// Limitation: this method runs asynchronously but can not be awaited.
  /// The queries are queued so this method can
  /// be safely called concurrently
  void push(String key, dynamic value) {
    final List<dynamic> kv = <dynamic>[key, value];
    _changefeed.sink.add(kv);
    if (inMemory == true) _inMemoryStore[key] = value;
  }

  /// Count the keys in the store
  Future<int> count() async {
    int n = 0;
    try {
      n = await _db.count(table: "kvstore");
    } catch (e) {
      throw ("Can not count keys in the store $e");
    }
    return n;
  }

  /// Synchronously get a value from the in memory store
  ///
  /// The [inMemory] option must be set to true when initilializing
  /// the store for this to work
  T selectSync<T>(String key) {
    if (!inMemory) {
      throw (ArgumentError("The [inMemory] parameter must be set " +
          "to true at database initialization to use select sync methods"));
    }
    dynamic value;
    try {
      if (_inMemoryStore.containsKey(key) == true) {
        value = _inMemoryStore[key];
        if (!(value is T)) {
          throw (ArgumentError("The selected value is of type " +
              "${value.runtimeType} and should be $T"));
        }
      } else {
        return null;
      }
    } catch (e) {
      throw ("Can not select data $e");
    }
    if (verbose) {
      print("# KVstore: select $key : $value");
    }
    if (value == null) {
      return null;
    }
    return value as T;
  }

  /// synchronously select a map
  Map<T, T2> selectMapSync<T, T2>(String key) => selectSync<Map<T, T2>>(key);

  /// synchronously select a list
  List<T> selectListSync<T>(String key) => selectSync<List<T>>(key);

  Future<void> _runQueue() async {
    await for (final item in _changefeed.stream) {
      final String k = item[0].toString();
      final dynamic v = item[1];
      unawaited(upsert<dynamic>(k, v));
    }
  }

  /// Dispose the store
  void dispose() {
    _changefeed.close();
  }
}
