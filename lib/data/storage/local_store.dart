import 'local_store_io.dart'
    if (dart.library.html) 'local_store_web.dart' as impl;

abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

LocalStore createLocalStore() => impl.createLocalStore();
