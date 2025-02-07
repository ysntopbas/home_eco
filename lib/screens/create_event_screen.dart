import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Etkinlik Oluştur', style: theme.textTheme.titleLarge),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Etkinlik Adı',
                        border: const OutlineInputBorder(),
                        labelStyle: theme.textTheme.bodyLarge,
                      ),
                      style: theme.textTheme.bodyLarge,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen etkinlik adı giriniz';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Açıklama',
                        border: const OutlineInputBorder(),
                        labelStyle: theme.textTheme.bodyLarge,
                      ),
                      style: theme.textTheme.bodyLarge,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        _selectedDate == null
                            ? 'Tarih Seçin'
                            : 'Tarih: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text('Etkinlik Oluştur'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _createEvent() async {
    final theme = Theme.of(context);
    
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() => _isLoading = true);
      try {
        final inviteCode = await _firebaseService.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate!,
        );

        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              'Etkinlik Oluşturuldu',
              style: theme.textTheme.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Etkinlik başarıyla oluşturuldu. Davet kodu:',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectableText(
                      inviteCode,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: theme.colorScheme.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Kod kopyalandı'),
                            backgroundColor: theme.colorScheme.secondary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Dialog'u kapat
                  Navigator.of(context).pop(); // Etkinlik oluşturma ekranından çık
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen bir tarih seçin'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
