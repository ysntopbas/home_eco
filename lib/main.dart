import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Clipboard için gerekli
import 'models/house.dart';
import 'services/firebase_service.dart';
import 'services/device_service.dart';
import 'screens/create_house_screen.dart';
import 'screens/join_house_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/join_event_screen.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  Future<void> _loadHouses() async {
    setState(() => _isLoading = true);
    try {
      final userId = await DeviceService.getUserId();
      final houses = await _firebaseService.getUserHouses();
      setState(() {
        _ownedHouses = houses.where((house) => house.ownerId == userId).toList();
      });
    } catch (e) {
      // Hata yönetimi
    } finally {
      setState(() => _isLoading = false);
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
        content: Text('${house.name} evini silmek istediğinizden emin misiniz?'),
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
                    const SnackBar(content: Text('Ev silinirken bir hata oluştu')),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Color.fromARGB(255, 255, 71, 71))),
          ),
        ],
      ),
    );
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
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        HomeCard(
                          title: 'Ev Oluştur',
                          icon: Icons.home_outlined,
                          onTap: _ownedHouses.isEmpty
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CreateHouseScreen(),
                                    ),
                                  );
                                  _loadHouses();
                                }
                              : null,
                          isDisabled: _ownedHouses.isNotEmpty,
                        ),
                        HomeCard(
                          title: 'Eve Katıl',
                          icon: Icons.group_add,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const JoinHouseScreen(),
                              ),
                            );
                          },
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
                            );
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
                    if (_ownedHouses.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Sahibi Olduğum Evler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                    icon: const Icon(Icons.share),
                                    onPressed: () => _showInviteCode(house.inviteCode),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.grey),
                                    onPressed: () => _confirmDelete(house),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
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
