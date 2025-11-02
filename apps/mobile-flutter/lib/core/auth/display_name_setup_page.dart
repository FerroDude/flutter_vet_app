import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class DisplayNameSetupPage extends StatefulWidget {
  const DisplayNameSetupPage({super.key});

  @override
  State<DisplayNameSetupPage> createState() => _DisplayNameSetupPageState();
}

class _DisplayNameSetupPageState extends State<DisplayNameSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Display Name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome! Choose how your name appears to others.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Display name is required';
                  if (v.length < 2) return 'Please enter at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _submitting = true);
                          final ok = await context
                              .read<UserProvider>()
                              .updateProfile(
                                displayName: _nameController.text.trim(),
                              );
                          if (!mounted || !context.mounted) return;
                          setState(() => _submitting = false);
                          if (ok) {
                            if (!context.mounted) return;
                            Navigator.of(context).maybePop();
                          } else {
                            if (!context.mounted) return;
                            final err =
                                context.read<UserProvider>().error ?? 'Error';
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                          }
                        },
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
