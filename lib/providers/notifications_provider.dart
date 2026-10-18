//The bell's state, shared by every page that draws it.
//
//A PROVIDER RATHER THAN A FETCH PER PAGE, because the badge is in the app bar
//of all three main pages at once. Three copies of the same list would mean
//three requests on every tab change and a count that disagrees with itself.
//
//THE SERVER IS THE TRUTH AND THIS IS A CACHE OF IT. Reading one marks it read
//locally first and sends the request behind that - the row dims the instant it
//is tapped, which is the only feedback that matters, and a failed request
//costs nothing worse than a badge that comes back on the next refresh.

import 'package:flutter/foundation.dart';
import 'package:foitifinder/models/notification_model.dart';
import 'package:foitifinder/services/api_services.dart';

class NotificationsProvider extends ChangeNotifier {
  List<AppNotification> _items = const [];
  bool _loading = false;

  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  int get unreadCount => _items.where((note) => !note.read).length;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      _items = await ApiService.getNotifications();
    } catch (_) {
      //keep whatever was already on screen: an empty bell should mean "nothing
      //happened", never "the network is down"
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification note) async {
    if (note.read) return;

    _items = [
      for (final item in _items) item.id == note.id ? item.asRead() : item,
    ];
    notifyListeners();

    try {
      await ApiService.markNotificationRead(note.id);
    } catch (_) {
      //the server still has it unread; the next load will say so
    }
  }

  //signed out: the next account must not inherit this one's bell
  void clear() {
    _items = const [];
    notifyListeners();
  }
}
