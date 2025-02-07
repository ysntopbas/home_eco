import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard için gerekli
import 'models/house.dart';
import 'models/event.dart';
import 'services/firebase_service.dart';
import 'screens/create_house_screen.dart';
import 'screens/join_house_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/join_event_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'screens/detail_page.dart';
import 'models/payment_info.dart';
import 'providers/theme_provider.dart'; // CustomColors sınıfı burada
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ortam değişkenlerini yükleyin
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Ev Ekonomi App',
          theme: themeProvider.currentTheme,
          home: StreamBuilder<User?>(
            stream: AuthService().authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeScreen(),
          },
        ),
      ),
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
  List<House> _memberHouses = [];
  List<Event> _createdEvents = [];
  List<Event> _joinedEvents = [];
  List<PaymentInfo> _payments = [];
  bool _isLoading = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_mounted) return;

    try {
      setState(() => _isLoading = true);
      
      // Tüm verileri paralel olarak yükle
      await Future.wait([
        _loadHouses(),
        _loadEvents(),
        _loadPayments(),
      ]);
      
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler yüklenirken hata oluştu: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHouses() async {
    if (!_mounted) return;

    try {
      final currentUserId = await _firebaseService.getUserId();
      final houses = await _firebaseService.getUserHouses();
      
      if (_mounted) {
        setState(() {
          _ownedHouses = houses.where((house) => house.ownerId == currentUserId).toList();
          _memberHouses = houses.where((house) => 
            house.memberIds.contains(currentUserId) && house.ownerId != currentUserId
          ).toList();
        });
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Evler yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _loadEvents() async {
    if (!_mounted) return;

    try {
      final currentUserId = await _firebaseService.getUserId();
      final events = await _firebaseService.getUserEvents();
      
      if (_mounted) {
        setState(() {
          _createdEvents = events.where((event) => event.creatorId == currentUserId).toList();
          _joinedEvents = events.where((event) => 
            event.participantIds.contains(currentUserId) && event.creatorId != currentUserId
          ).toList();
        });
      }
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlikler yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _loadPayments() async {
    if (!_mounted) return;

    try {
      final payments = await _firebaseService.getUserPayments();
      if (_mounted) {
        setState(() {
          _payments = payments;
        });
      }
    } catch (e) {
      print('Ödemeler yüklenirken hata: $e');
      if (_mounted) {
        setState(() {
          _payments = [];
        });
      }
    }
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
                if (_mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ev başarıyla silindi')),
                  );
                }
              } catch (e) {
                if (_mounted) {
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
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: const Text('Bu etkinliği silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firebaseService.deleteEvent(event.id);
                if (_mounted) {
                  Navigator.pop(context);
                  _loadEvents(); // Etkinlikleri yeniden yükle
                }
              } catch (e) {
                if (_mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Etkinlik silinemedi: $e')),
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
      final participants = await _firebaseService.getEventParticipants(event.id);
      if (!_mounted) return;

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
      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Katılımcılar yüklenirken hata oluştu: $e')),
      );
    }
  }

  Widget _buildPaymentsList() {
    final debts = _payments.where((p) => p.isDebt).toList();
    final receivables = _payments.where((p) => !p.isDebt).toList();

    if (debts.isEmpty && receivables.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalDebt = debts.fold<double>(0, (sum, payment) => sum + payment.amount);
    final totalReceivable = receivables.fold<double>(0, (sum, payment) => sum + payment.amount);

    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        leading: const Icon(Icons.notifications),
        title: Text(
          'Bildirimler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (debts.isNotEmpty) ...[
                  Text(
                    'Toplam Borcunuz: ${totalDebt.toStringAsFixed(2)}₺',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: customColors?.negativeBalance,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Borç Detayları:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: debts.length,
                    itemBuilder: (context, index) {
                      final payment = debts[index];
                      return ListTile(
                        title: Text(
                          payment.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          payment.parentName,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: Text(
                          '${payment.amount.toStringAsFixed(2)}₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: customColors?.negativeBalance,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (receivables.isNotEmpty) ...[
                  if (debts.isNotEmpty) const SizedBox(height: 24),
                  Text(
                    'Toplam Alacağınız: ${totalReceivable.toStringAsFixed(2)}₺',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: customColors?.positiveBalance,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Alacak Detayları:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: receivables.length,
                    itemBuilder: (context, index) {
                      final payment = receivables[index];
                      return ListTile(
                        title: Text(
                          payment.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          payment.parentName,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: Text(
                          '${payment.amount.toStringAsFixed(2)}₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: customColors?.positiveBalance,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(PaymentInfo payment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(
          item: payment.type == 'house' 
              ? _ownedHouses.firstWhere((h) => h.id == payment.parentId, 
                  orElse: () => _memberHouses.firstWhere((h) => h.id == payment.parentId))
              : _createdEvents.firstWhere((e) => e.id == payment.parentId,
                  orElse: () => _joinedEvents.firstWhere((e) => e.id == payment.parentId)),
          type: payment.type,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ana Sayfa', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: themeProvider.isDarkMode ? 'Açık Tema' : 'Koyu Tema',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.primary),
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _loadData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPaymentsList(),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          HomeCard(
                            title: 'Ev Oluştur',
                            icon: Icons.home_outlined,
                            onTap: (_ownedHouses.isNotEmpty ||
                                    _memberHouses.isNotEmpty)
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
                            isDisabled: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty,
                            color: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.surface.withOpacity(0.7)
                                    : theme.cardColor,
                            iconColor: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.primary.withOpacity(0.7)
                                    : theme.colorScheme.primary,
                            textColor: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.primary.withOpacity(0.7)
                                    : theme.colorScheme.onSurface,
                          ),
                          HomeCard(
                            title: 'Eve Katıl',
                            icon: Icons.group_add,
                            onTap: (_ownedHouses.isNotEmpty ||
                                    _memberHouses.isNotEmpty)
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
                            isDisabled: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty,
                            color: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.surface.withOpacity(0.7)
                                    : theme.cardColor,
                            iconColor: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.primary.withOpacity(0.7)
                                    : theme.colorScheme.primary,
                            textColor: _ownedHouses.isNotEmpty ||
                                _memberHouses.isNotEmpty
                                    ? theme.colorScheme.primary.withOpacity(0.7)
                                    : theme.colorScheme.onSurface,
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
                              ).then((_) => _loadData());
                            },
                            color: theme.cardColor,
                            iconColor: theme.colorScheme.primary,
                            textColor: theme.colorScheme.onSurface,
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
                            color: theme.cardColor,
                            iconColor: theme.colorScheme.primary,
                            textColor: theme.colorScheme.onSurface,
                          ),
                        ],
                      ),
                      if (_createdEvents.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ExpansionTile(
                          leading: Icon(Icons.event, color: theme.colorScheme.primary),
                          title: Text(
                            'Oluşturduğum Etkinlikler',
                            style: theme.textTheme.titleLarge,
                          ),
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _createdEvents.length,
                              itemBuilder: (context, index) {
                                final event = _createdEvents[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      event.title,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    subtitle: Text(
                                      DateFormat('dd/MM/yyyy').format(event.date),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.people),
                                          onPressed: () => _showEventParticipants(event),
                                          tooltip: 'Katılımcılar',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.share),
                                          onPressed: () => _showInviteCode(event.inviteCode),
                                          tooltip: 'Davet Kodu',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _confirmDeleteEvent(event),
                                          tooltip: 'Etkinliği Sil',
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailPage(
                                            item: event,
                                            type: 'event',
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                  },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      if (_joinedEvents.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ExpansionTile(
                          leading: Icon(Icons.event_available, color: theme.colorScheme.primary),
                          title: Text(
                            'Katıldığım Etkinlikler',
                            style: theme.textTheme.titleLarge,
                          ),
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _joinedEvents.length,
                              itemBuilder: (context, index) {
                                final event = _joinedEvents[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      event.title,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    subtitle: Text(
                                      DateFormat('dd/MM/yyyy').format(event.date),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.people),
                                      onPressed: () => _showEventParticipants(event),
                                      tooltip: 'Katılımcılar',
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailPage(
                                            item: event,
                                            type: 'event',
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                    },
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
                          leading: Icon(Icons.home, color: theme.colorScheme.primary),
                          title: Text(
                            'Sahibi Olduğum Evler',
                            style: theme.textTheme.titleLarge,
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
                                    title: Text(
                                      house.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.people),
                                          onPressed: () => _showHouseMembers(house),
                                          tooltip: 'Ev Üyeleri',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.share),
                                          onPressed: () => _showInviteCode(house.inviteCode),
                                          tooltip: 'Davet Kodu',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _confirmDelete(house),
                                          tooltip: 'Evi Sil',
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailPage(
                                            item: house,
                                            type: 'house',
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      if (_memberHouses.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ExpansionTile(
                          leading: Icon(Icons.home_work, color: theme.colorScheme.primary),
                          title: Text(
                            'Üyesi Olduğum Evler',
                            style: theme.textTheme.titleLarge,
                          ),
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _memberHouses.length,
                              itemBuilder: (context, index) {
                                final house = _memberHouses[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      house.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.people),
                                      onPressed: () => _showHouseMembers(house),
                                      tooltip: 'Ev Üyeleri',
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailPage(
                                            item: house,
                                            type: 'house',
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                    },
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
      ),
    );
  }

  void _showHouseMembers(House house) async {
    try {
      final members = await _firebaseService.getHouseMembers(house.id);
      if (!_mounted) return;

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
      if (!_mounted) return;
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
  final Color color;
  final Color iconColor;
  final Color textColor;

  const HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDisabled = false,
    required this.color,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDisabled ? 0 : 4,
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
