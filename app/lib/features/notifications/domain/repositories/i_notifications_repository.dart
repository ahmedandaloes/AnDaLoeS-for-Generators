abstract interface class INotificationsRepository {
  Future<List<Map<String, dynamic>>> fetch({int limit = 50});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
}
