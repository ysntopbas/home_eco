import 'package:flutter/material.dart';

class JoinHouseScreen extends StatefulWidget {
  const JoinHouseScreen({super.key});

  @override
  State<JoinHouseScreen> createState() => _JoinHouseScreenState();
}

class _JoinHouseScreenState extends State<JoinHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eve Katıl'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Davet Kodu',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen davet kodunu giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Eve katılma işlemi
                  }
                },
                child: const Text('Katıl'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 