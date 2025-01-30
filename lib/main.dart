import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard için gerekli
import 'models/house.dart';
import 'models/event.dart';
import 'services/firebase_service.dart';
import 'services/device_service.dart';
import 'screens/create_house_screen.dart';
import 'screens/join_house_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/join_event_screen.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ev Ekonomi App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<House> _ownedHouses = [];
  List<Event> _events = [];
  bool _isLoading = true;
  String? _currentUserId; // Kullanıcı ID'sini saklayacak değişken

  @override
  void initState() {
    super.initState();
    _initializeUserId(); // Kullanıcı ID'sini başlangıçta al
  }

  Future<void> _initializeUserId() async {
    _currentUserId = await DeviceService.getUserId();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadHouses(),
        _loadEvents(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHouses() async {
    try {
      final userId = await DeviceService.getUserId();
      final houses = await _firebaseService.getUserHouses();
      setState(() {
        _ownedHouses =
            houses.where((house) => house.ownerId == userId).toList();
      });
    } catch (e) {
      // Hata yönetimi
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _firebaseService.getUserEvents();
      if (mounted) {
        setState(() {
          _events = events;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlikler yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  // Ana ekrana döndükten sonra etkinlikleri yenileme
  void _refreshEvents() async {
    await _loadEvents();
  }

  void _showInviteCode(String inviteCode) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Davet Kodu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu kodu arkadaşlarınızla paylaşın:'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  inviteCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Kod kopyalandı')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(House house) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Evi Sil'),
        content:
            Text('${house.name} evini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firebaseService.deleteHouse(house.id);
                _loadHouses(); // Listeyi yenile
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ev başarıyla silindi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ev silinirken bir hata oluştu')),
                  );
                }
              }
            },
            child: const Text('Sil',
                style: TextStyle(color: Color.fromARGB(255, 255, 71, 71))),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: Text(
            '${event.title} etkinliğini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firebaseService.deleteEvent(event.id);
                await _loadEvents(); // Listeyi yenile
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Etkinlik başarıyla silindi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Etkinlik silinirken hata oluştu: $e')),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEventParticipants(Event event) async {
    try {
      final participants =
          await _firebaseService.getEventParticipants(event.id);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${event.title} Katılımcıları'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: participants
                  .map(
                    (participant) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• ${participant.name}',
                        style: TextStyle(
                          fontWeight: participant.id == event.creatorId
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Katılımcılar yüklenirken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ev Ekonomi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        HomeCard(
                          title: 'Ev Oluştur',
                          icon: Icons.home_outlined,
                          onTap: _ownedHouses.isNotEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateHouseScreen(),
                                    ),
                                  ).then((_) => _loadHouses());
                                },
                          isDisabled: _ownedHouses.isNotEmpty,
                        ),
                        HomeCard(
                          title: 'Eve Katıl',
                          icon: Icons.group_add,
                          onTap: _ownedHouses.isNotEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const JoinHouseScreen(),
                                    ),
                                  ).then((_) => _loadHouses());
                                },
                          isDisabled: _ownedHouses.isNotEmpty,
                        ),
                        HomeCard(
                          title: 'Etkinlik Oluştur',
                          icon: Icons.event_available,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateEventScreen(),
                              ),
                            ).then((_) => _refreshEvents());
                          },
                        ),
                        HomeCard(
                          title: 'Etkinliğe Katıl',
                          icon: Icons.event_note,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const JoinEventScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_events.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ExpansionTile(
                        leading: const Icon(Icons.event, size: 28),
                        title: const Text(
                          'Etkinliklerim',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              final formattedDate =
                                  DateFormat('dd/MM/yyyy').format(event.date);
                              return Card(
                                child: ListTile(
                                  title: Text(event.title),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Tarih: $formattedDate'),
                                      Text('Oluşturan: ${event.creatorName}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.people),
                                        onPressed: () =>
                                            _showEventParticipants(event),
                                        tooltip: 'Katılımcılar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share),
                                        onPressed: () =>
                                            _showInviteCode(event.inviteCode),
                                        tooltip: 'Davet Kodu',
                                      ),
                                      if (_currentUserId != null &&
                                          event.creatorId == _currentUserId)
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _confirmDeleteEvent(event),
                                          tooltip: 'Etkinliği Sil',
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    if (_ownedHouses.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ExpansionTile(
                        leading: const Icon(Icons.home, size: 28),
                        title: const Text(
                          'Sahibi Olduğum Evler',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _ownedHouses.length,
                            itemBuilder: (context, index) {
                              final house = _ownedHouses[index];
                              return Card(
                                child: ListTile(
                                  title: Text(house.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.people),
                                        onPressed: () =>
                                            _showHouseMembers(house),
                                        tooltip: 'Ev Üyeleri',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share),
                                        onPressed: () =>
                                            _showInviteCode(house.inviteCode),
                                        tooltip: 'Davet Kodu',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _confirmDelete(house),
                                        tooltip: 'Evi Sil',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  void _showHouseMembers(House house) async {
    try {
      final members = await _firebaseService.getHouseMembers(house.id);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${house.name} Üyeleri'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: members
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• ${member.name}',
                        style: TextStyle(
                          fontWeight: member.id == house.ownerId
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üyeler yüklenirken hata oluştu: $e')),
      );
    }
  }
}

class HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDisabled;

  const HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDisabled ? 0 : 4,
      color: isDisabled ? Colors.grey[300] : null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isDisabled
                  ? Colors.grey[600]
                  : Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDisabled ? Colors.grey[600] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
