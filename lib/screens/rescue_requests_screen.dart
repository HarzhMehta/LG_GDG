import 'package:flutter/material.dart';
import '../controllers/lg_controller.dart';
import '../widgets/neu_button.dart';

class RescueRequestsScreen extends StatefulWidget {
  final LGController lgController;

  const RescueRequestsScreen({super.key, required this.lgController});

  @override
  State<RescueRequestsScreen> createState() => _RescueRequestsScreenState();
}

class _RescueRequestsScreenState extends State<RescueRequestsScreen> {
  // Mock Data
  final List<Map<String, dynamic>> _requests = [
    {
      'id': '1',
      'location': 'Aluva Bridge, Kochi',
      'lat': 10.1071,
      'lng': 76.3550,
      'time': '10 mins ago',
      'status': 'PENDING',
      'description': 'Family of 4 stranded on roof.'
    },
    {
      'id': '2',
      'location': 'Kaloor Stadium',
      'lat': 9.9981,
      'lng': 76.3000,
      'time': '25 mins ago',
      'status': 'ACKNOWLEDGED',
      'description': 'Medical emergency, insulin needed.'
    },
    {
      'id': '3',
      'location': 'Edappally Toll',
      'lat': 10.0236,
      'lng': 76.3116,
      'time': '40 mins ago',
      'status': 'PENDING',
      'description': 'Water level rising rapidly.'
    },
  ];

  Future<void> _showOnLG(double lat, double lng) async {
    try {
      await widget.lgController.sendRescueMarker(lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rescue Point Sent to Liquid Galaxy'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to LG'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewOnMap(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Rescue Location', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Place: ${request['location']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Coords: ${request['lat']}, ${request['lng']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Detail: ${request['description']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.grey.shade800,
              alignment: Alignment.center,
              child: const Icon(Icons.map, size: 48, color: Colors.white24),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('(Map Preview Placeholder)', style: TextStyle(color: Colors.white24, fontSize: 12)),
            )
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rescue Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final req = _requests[index];
              return _buildRequestCard(req);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final isPending = req['status'] == 'PENDING';
    final statusColor = isPending ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sos, color: statusColor),
            ),
            title: Text(
              req['location'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${req['time']} • ${req['description']}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                req['status'],
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewOnMap(req),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showOnLG(req['lat'], req['lng']),
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: const Text('LG Cast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900.withOpacity(0.5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
