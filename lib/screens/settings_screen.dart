import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/ssh_controller.dart';
import '../controllers/settings_controller.dart';
import '../helpers/snackbar_helper.dart';
import '../helpers/debug_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final SSHController sshController;
  final SettingsController settingsController;

  const SettingsScreen({
    super.key,
    required this.sshController,
    required this.settingsController,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _rigsNumController;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    DebugHelper.log('SETTINGS_SCREEN', 'Initializing with current settings: Host=${widget.settingsController.lgHost}, Port=${widget.settingsController.lgPort}');
    _hostController = TextEditingController(text: widget.settingsController.lgHost);
    _portController = TextEditingController(text: widget.settingsController.lgPort.toString());
    _usernameController = TextEditingController(text: widget.settingsController.lgUsername);
    _passwordController = TextEditingController(text: widget.settingsController.lgPassword);
    _rigsNumController = TextEditingController(text: widget.settingsController.lgRigsNum.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rigsNumController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      DebugHelper.log('SETTINGS_SCREEN', 'Testing connection with Host=${_hostController.text}, Port=${_portController.text}, User=${_usernameController.text}');
      final success = await widget.sshController.connect(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        if (success) {
          DebugHelper.success('SETTINGS_SCREEN', 'Test connection successful!');
          _showConnectionSuccessDialog();
        } else {
          // Connection returned false - show error
          final errorMsg = widget.sshController.lastError ?? 'Connection failed - unknown error';
          DebugHelper.error('SETTINGS_SCREEN', 'Test connection returned false: $errorMsg');
          _showConnectionErrorDialog(errorMsg);
        }
      }
    } catch (e, stackTrace) {
      DebugHelper.error('SETTINGS_SCREEN', 'Test connection failed', e, stackTrace);
      if (mounted) {
        _showConnectionErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showConnectionSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Connection Successful'),
          ],
        ),
        content: const Text(
          '✅ Connected to LG master successfully!\n\n'
          'Your settings are correct. You can now use the control buttons.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConnectionErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Connection Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Error Details:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildTroubleshootingItem(
                icon: Icons.router,
                title: 'Network Issue?',
                hint: 'Ping the IP: ping ${_hostController.text}',
              ),
              _buildTroubleshootingItem(
                icon: Icons.vpn_lock,
                title: 'Wrong Password?',
                hint: 'Check your LG credentials in settings',
              ),
              _buildTroubleshootingItem(
                icon: Icons.storage,
                title: 'SSH Not Running?',
                hint: 'SSH service might be disabled on LG',
              ),
              _buildTroubleshootingItem(
                icon: Icons.info,
                title: 'Wrong IP?',
                hint: 'Default LG master IP is usually 10.0.2.10',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  hint,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      DebugHelper.log('SETTINGS_SCREEN', 'Saving settings...');
      await widget.settingsController.saveSettings(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        password: _passwordController.text,
        rigsNum: int.parse(_rigsNumController.text),
      );

      if (mounted) {
        DebugHelper.success('SETTINGS_SCREEN', 'Settings saved successfully');
        showSnackBar(
          context: context,
          message: 'Settings saved successfully!',
          color: Colors.green,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      DebugHelper.error('SETTINGS_SCREEN', 'Failed to save settings', e);
      if (mounted) {
        showSnackBar(
          context: context,
          message: 'Error saving settings: ${e.toString()}',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Liquid Galaxy connection',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your rig details and keep them handy while you work. Test once, then you are good to go.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Master IP Address',
                          hintText: '10.0.2.10',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter IP address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'SSH Port',
                          hintText: '22',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter port number';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid port number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'lg',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rigsNumController,
                        decoration: const InputDecoration(
                          labelText: 'Number of Rigs',
                          hintText: '3',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter number of rigs';
                          }
                          final num = int.tryParse(value);
                          if (num == null || num < 1) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_isLoading ? 'Testing...' : 'Connect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
