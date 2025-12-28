import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/ssh_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/lg_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final SSHController sshController;
  final SettingsController settingsController;
  final LGController lgController;

  const HomeScreen({
    super.key,
    required this.sshController,
    required this.settingsController,
    required this.lgController,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isConnected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.settingsController.lgHost.isNotEmpty && 
        widget.settingsController.lgPassword.isNotEmpty) {
      _checkConnection();
    }
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.settingsController.lgHost.isEmpty || 
          widget.settingsController.lgPassword.isEmpty) {
        setState(() => _isConnected = false);
        return;
      }
      
      final success = await widget.sshController.connect(
        host: widget.settingsController.lgHost,
        port: widget.settingsController.lgPort,
        username: widget.settingsController.lgUsername,
        password: widget.settingsController.lgPassword,
      );
      
      setState(() => _isConnected = success);
    } catch (e) {
      setState(() => _isConnected = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLogoToLeftScreen() async {
    try {
      setState(() => _isLoading = true);
      
      await widget.lgController.sendLogoToLeftScreen(
        assetPath: 'assets/logo.png',
        logoScreenNumber: 3,
      );
      
      // Execute lg-relaunch command via SSH
      await widget.lgController.relaunch();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo sent to left screen and lg-relaunch executed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearLogoFromLeftScreen() async {
    try {
      setState(() => _isLoading = true);
      
      await widget.lgController.clearLogoFromLeftScreen(
        logoScreenNumber: 3,
      );
      
      // Execute lg-relaunch command via SSH
      await widget.lgController.relaunch();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo cleared and lg-relaunch executed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          sshController: widget.sshController,
          settingsController: widget.settingsController,
        ),
      ),
    );

    if (result == true) {
      _checkConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquid Galaxy Controller'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isConnected 
                        ? [Colors.green.shade50, Colors.green.shade100]
                        : [Colors.red.shade50, Colors.red.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConnected ? 'Connected' : 'Disconnected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                            if (_isConnected)
                              Text(
                                'LG Master: ${widget.settingsController.lgHost}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              )
                            else
                              const Text(
                                'Configure settings to connect',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_isConnected)
                        ElevatedButton(
                          onPressed: _navigateToSettings,
                          child: const Text('Configure'),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildControlButton(
                        icon: Icons.image,
                        label: 'Send Logo\n(Left Screen)',
                        color: Colors.blue,
                        onPressed: _isConnected
                            ? _sendLogoToLeftScreen
                            : null,
                      ),
                      _buildControlButton(
                        icon: Icons.hide_image,
                        label: 'Clear Logo\n(Left Screen)',
                        color: Colors.purple,
                        onPressed: _isConnected
                            ? _clearLogoFromLeftScreen
                            : null,
                      ),
                      _buildControlButton(
                        icon: Icons.location_on,
                        label: 'Send KML #1',
                        color: Colors.green,
                        onPressed: _isConnected
                            ? () => widget.lgController.sendKml1()
                            : null,
                      ),
                      _buildControlButton(
                        icon: Icons.place,
                        label: 'Send KML #2',
                        color: Colors.orange,
                        onPressed: _isConnected
                            ? () => widget.lgController.sendKml2()
                            : null,
                      ),
                      _buildControlButton(
                        icon: Icons.cleaning_services,
                        label: 'Clear All Logos',
                        color: Colors.red.shade300,
                        onPressed: _isConnected
                            ? () => widget.lgController.clearLogos()
                            : null,
                      ),
                      _buildControlButton(
                        icon: Icons.clear_all,
                        label: 'Clear KMLs',
                        color: Colors.red,
                        onPressed: _isConnected
                            ? () => widget.lgController.clearKmls()
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    
    return Material(
      elevation: isEnabled ? 3 : 1,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isEnabled
                ? LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: isEnabled ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.white : Colors.grey.shade600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
