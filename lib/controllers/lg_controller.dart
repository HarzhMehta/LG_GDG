import 'package:flutter/foundation.dart';
import 'ssh_controller.dart';
import 'settings_controller.dart';

class LGController {
  LGController({
    required SSHController sshController,
    required SettingsController settingsController,
  })  : _sshController = sshController,
        _settingsController = settingsController,
        screenAmount = settingsController.lgRigsNum;

  final SSHController _sshController;
  final SettingsController _settingsController;

  int screenAmount;

  String? _lastUpdatedKmlPath;

  bool get isConnected => _sshController.isConnected;
  String? get lastError => _sshController.lastError;

  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    if (kDebugMode) {
      print('LGController: connect to $host:$port');
    }

    final success = await _sshController.connect(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    if (success) {
      await _settingsController.saveSettings(
        host: host,
        port: port,
        username: username,
        password: password,
        rigsNum: screenAmount,
      );
    }

    return success;
  }

  Future<void> disconnect() async {
    _sshController.disconnect();
  }

  Future<String> executeCommand(String command) async {
    if (!isConnected) throw Exception('Not connected to LG');
    return _sshController.executeCommand(command);
  }

  Future<Map<String, dynamic>> loadSettings() async {
    return _settingsController.loadSettings();
  }

  Future<void> saveSettings({
    required String host,
    required int port,
    required String username,
    required String password,
    required int rigsNum,
  }) async {
    screenAmount = rigsNum;
    await _settingsController.saveSettings(
      host: host,
      port: port,
      username: username,
      password: password,
      rigsNum: rigsNum,
    );
  }

  int getLogoScreen() {
    if (screenAmount <= 1) return 1;
    return (screenAmount / 2).floor() + 2;
  }

  int get firstScreen => screenAmount <= 1 ? 1 : (screenAmount / 2).floor() + 2;
  int get lastScreen => screenAmount <= 1 ? 1 : (screenAmount / 2).floor();

  Future<void> sendKMLToSlave(int screen, String content) async {
    if (!isConnected) throw Exception('Not connected to LG');
    await _sshController.uploadString(content, '/var/www/html/kml/slave_$screen.kml');
    _lastUpdatedKmlPath = '/var/www/html/kml/slave_$screen.kml';
  }

  Future<void> query(String content) async {
    if (!isConnected) throw Exception('Not connected to LG');
    await executeCommand('echo "$content" > /tmp/query.txt');
  }

  Future<void> sendKml1() async {
    if (!isConnected) throw Exception('Not connected to LG');

    await _sshController.uploadAsset('assets/kml1.kml', '/var/www/html/kml1.kml');
    await Future.delayed(const Duration(milliseconds: 300));
    await executeCommand("echo '\nhttp://${_settingsController.lgHost}:81/kml1.kml' > /var/www/html/kmls.txt");
    await Future.delayed(const Duration(milliseconds: 300));
    await query('flytoview=<LookAt><longitude>-77.058654</longitude><latitude>38.872036</latitude><range>2000</range><tilt>60</tilt><heading>0</heading></LookAt>');
  }

  Future<void> sendKml2() async {
    if (!isConnected) throw Exception('Not connected to LG');

    await _sshController.uploadAsset('assets/kml2.kml', '/var/www/html/kml2.kml');
    await Future.delayed(const Duration(milliseconds: 300));
    await executeCommand("echo '\nhttp://${_settingsController.lgHost}:81/kml2.kml' > /var/www/html/kmls.txt");
    await Future.delayed(const Duration(milliseconds: 300));
    await query('flytoview=<LookAt><longitude>2.2945</longitude><latitude>48.8584</latitude><range>2000</range><tilt>60</tilt><heading>0</heading></LookAt>');
  }

  Future<void> sendDisasterLayer({
    required String assetPath,
  }) async {
    if (!isConnected) throw Exception('Not connected to LG');

    // Clear previous KMLs first (optional based on UX, but requested to "Optionally clear previous")
    // I'll clear them to ensure single-layer focus as per "No multi-selection needed"
    await query('exittour=true');
    await executeCommand('> /var/www/html/kmls.txt');
    await Future.delayed(const Duration(milliseconds: 200));

    // Upload file
    final fileName = assetPath.split('/').last;
    final remotePath = '/var/www/html/$fileName';
    
    await _sshController.uploadAsset(assetPath, remotePath);
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Add to kmls.txt
    final url = 'http://${_settingsController.lgHost}:81/$fileName';
    await executeCommand("echo '\n$url' > /var/www/html/kmls.txt");
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> sendRescueMarker(double lat, double lng) async {
    if (!isConnected) throw Exception('Not connected to LG');

    // Create dynamic KML
    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Rescue Request</name>
    <Style id="rescue_style">
      <IconStyle>
        <scale>1.5</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/shapes/caution.png</href>
        </Icon>
        <color>ff0000ff</color>
      </IconStyle>
    </Style>
    <Placemark>
      <name>SOS REQUEST</name>
      <description>Rescue Needed Here</description>
      <styleUrl>#rescue_style</styleUrl>
      <Point>
        <coordinates>$lng,$lat,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';

    // Upload to slave_3 (usually right screen or main overlay screen) or just upload to server
    // For visibility, we'll put it in a specific KML file.
    const fileName = 'rescue_marker.kml';
    const remotePath = '/var/www/html/$fileName';
    
    await _sshController.uploadString(kml, remotePath);
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Add to kmls.txt if not there, or ensure it's loaded
    // We append it.
    final url = 'http://${_settingsController.lgHost}:81/$fileName';
    await executeCommand("grep -qF '$url' /var/www/html/kmls.txt || echo '\n$url' >> /var/www/html/kmls.txt");
    
    // Fly to location
    await query('flytoview=<LookAt><longitude>$lng</longitude><latitude>$lat</latitude><range>1000</range><tilt>60</tilt><heading>0</heading></LookAt>');
    await query('flytoview=<LookAt><longitude>$lng</longitude><latitude>$lat</latitude><range>1000</range><tilt>60</tilt><heading>0</heading></LookAt>');
  }

  Future<void> sendAreaSummary({
    required String areaName,
    required double lat,
    required double lng,
    required int count,
    required String priority,
  }) async {
    if (!isConnected) throw Exception('Not connected to LG');

    String colorHex;
    double scale;
    
    // Determine color and size
    switch (priority) {
      case 'High':
        colorHex = '990000ff'; // Red with transparency
        scale = 3.0 + (count * 0.2);
        break;
      case 'Medium':
        colorHex = '9900a5ff'; // Orange with transparency
        scale = 2.0 + (count * 0.1);
        break;
      case 'Low':
      default:
        colorHex = '9900ffff'; // Yellow with transparency
        scale = 1.5 + (count * 0.05);
        break;
    }

    final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Area Summary: $areaName</name>
    <Style id="area_style">
      <IconStyle>
        <scale>$scale</scale>
        <Icon>
           <href>http://maps.google.com/mapfiles/kml/shapes/donut.png</href>
        </Icon>
        <color>$colorHex</color>
      </IconStyle>
      <LabelStyle>
        <scale>1.5</scale>
      </LabelStyle>
    </Style>
    <Placemark>
      <name>$areaName ($count SOS)</name>
      <description>Priority: $priority</description>
      <styleUrl>#area_style</styleUrl>
      <Point>
        <coordinates>$lng,$lat,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';

    const fileName = 'area_summary.kml';
    const remotePath = '/var/www/html/$fileName';
    
    await _sshController.uploadString(kml, remotePath);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final url = 'http://${_settingsController.lgHost}:81/$fileName';
    await executeCommand("grep -qF '$url' /var/www/html/kmls.txt || echo '\n$url' >> /var/www/html/kmls.txt");
    
    // Fly to view
    await query('flytoview=<LookAt><longitude>$lng</longitude><latitude>$lat</latitude><range>3000</range><tilt>45</tilt><heading>0</heading></LookAt>');
  }

  Future<void> clearKmls({bool keepLogos = true}) async {
    if (!isConnected) throw Exception('Not connected to LG');

    await query('exittour=true');
    await Future.delayed(const Duration(milliseconds: 300));
    await executeCommand('> /var/www/html/kmls.txt');
    await Future.delayed(const Duration(milliseconds: 300));

    final logoScreen = getLogoScreen();

    for (int i = 2; i <= screenAmount; i++) {
      if (keepLogos && i == logoScreen) continue;
      
      final blankKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document id="slave_$i">
  </Document>
</kml>''';
      
      await _sshController.uploadString(blankKml, '/var/www/html/kml/slave_$i.kml');
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> clearLogos() async {
    if (!isConnected) throw Exception('Not connected to LG');
    await query('exittour=true');
    await executeCommand('echo "" > /var/www/html/kmls.txt');

    final logoScreen = firstScreen;
    final blankKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document id="slave_$logoScreen">
  </Document>
</kml>''';
    await _sshController.uploadString(blankKml, '/var/www/html/kml/slave_$logoScreen.kml');
    await refreshView(screen: logoScreen);
  }

  Future<void> setRefresh() async {
    if (!isConnected) throw Exception('Not connected to LG');

    final pw = _settingsController.lgPassword;
    final screenAmount = _settingsController.lgRigsNum;

    const search = '<href>##LG_PHPIFACE##kml\\/slave_{{slave}}.kml<\\/href>';
    const replace =
        '<href>##LG_PHPIFACE##kml\\/slave_{{slave}}.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>2<\\/refreshInterval>';

    final command =
        'echo $pw | sudo -S sed -i "s/$search/$replace/" ~/earth/kml/slave/myplaces.kml';
    final clear =
        'echo $pw | sudo -S sed -i "s/$replace/$search/" ~/earth/kml/slave/myplaces.kml';

    for (var i = 2; i <= screenAmount; i++) {
      final clearCmd = clear.replaceAll('{{slave}}', i.toString());
      final cmd = command.replaceAll('{{slave}}', i.toString());

      try {
        await executeCommand('sshpass -p $pw ssh -t lg$i \'$clearCmd\'');
        await executeCommand('sshpass -p $pw ssh -t lg$i \'$cmd\'');
      } catch (e) {
        debugPrint('Error setting refresh on lg\$i: \$e');
      }
    }
    await reboot();
  }

  Future<void> resetRefresh() async {
    if (!isConnected) throw Exception('Not connected to LG');

    final pw = _settingsController.lgPassword;
    final screenAmount = _settingsController.lgRigsNum;

    const search =
        '<href>##LG_PHPIFACE##kml\\/slave_{{slave}}.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>2<\\/refreshInterval>';
    const replace = '<href>##LG_PHPIFACE##kml\\/slave_{{slave}}.kml<\\/href>';

    final clear =
        'echo $pw | sudo -S sed -i "s/$search/$replace/" ~/earth/kml/slave/myplaces.kml';

    for (var i = 2; i <= screenAmount; i++) {
      final cmd = clear.replaceAll('{{slave}}', i.toString());
      try {
        await executeCommand('sshpass -p $pw ssh -t lg$i \'$cmd\'');
      } catch (e) {
        debugPrint('Error resetting refresh on lg\$i: \$e');
      }
    }
    await reboot();
  }

  Future<void> relaunch() async {
    if (!isConnected) throw Exception('Not connected to LG');

    final rigSettings = await _settingsController.loadSettings();
    final pw = rigSettings['password'] ?? '';

    for (int i = 1; i <= screenAmount; i++) {
      try {
        await executeCommand('sshpass -p $pw ssh -T -o StrictHostKeyChecking=no lg$i "export DISPLAY=:0 && /home/lg/bin/lg-relaunch"');
      } catch (e) {
        debugPrint('Relaunch error on lg$i: $e');
      }
    }
  }

  Future<void> reboot() async {
    if (!isConnected) throw Exception('Not connected to LG');

    final rigSettings = await _settingsController.loadSettings();
    final pw = rigSettings['password'] ?? '';

    for (int i = screenAmount; i >= 1; i--) {
      try {
        await executeCommand('sshpass -p $pw ssh -t lg$i "echo $pw | sudo -S reboot"');
      } catch (e) {
        debugPrint('Reboot error on lg$i: $e');
      }
    }
  }

  Future<void> poweroff() async {
    if (!isConnected) throw Exception('Not connected to LG');

    final rigSettings = await _settingsController.loadSettings();
    final pw = rigSettings['password'] ?? '';

    for (int i = screenAmount; i >= 1; i--) {
      try {
        await executeCommand('sshpass -p $pw ssh -t lg$i "echo $pw | sudo -S poweroff"');
      } catch (e) {
        debugPrint('Poweroff error on lg$i: $e');
      }
    }
  }

  Future<void> searchPlace(String placeName) async {
    if (!isConnected) throw Exception('Not connected to LG');
    await query('search=$placeName');
  }

  Future<void> setLogos({
    String name = 'LG-Dashboard',
    String content = '<name>Logos</name>',
  }) async {
    if (!isConnected) throw Exception('Not connected to LG');

    final logoKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$name</name>
    $content
    <ScreenOverlay>
      <name>Logo</name>
      <Icon>
        <href>https://raw.githubusercontent.com/LiquidGalaxy/liquid-galaxy/master/assets/lg_logo.png</href>
      </Icon>
      <color>ffffffff</color>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.02" y="0.95" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="500" y="400" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';

    await sendKMLToSlave(firstScreen, logoKml);
    await refreshView(screen: firstScreen);
  }

  Future<void> stopOrbit() async {
    if (!isConnected) throw Exception('Not connected to LG');
    await query('exittour=true');
  }

  Future<void> sendLogoToLeftScreen({
    required String assetPath,
    int? logoScreenNumber,
  }) async {
    if (!isConnected) throw Exception('Not connected to LG');

    screenAmount = _settingsController.lgRigsNum;
    final int targetScreen = logoScreenNumber ?? getLogoScreen();
    final String logoUrl = 'http://${_settingsController.lgHost}:81/kml/logo.png';

    const logoPath = '/var/www/html/kml/logo.png';
    await _sshController.uploadAsset(assetPath, logoPath);

    final logoKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Logos</name>
    <ScreenOverlay>
      <name>Logo</name>
      <Icon>
        <href>$logoUrl</href>
      </Icon>
      <color>ffffffff</color>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.02" y="0.95" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="200" y="160" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';

    await _sshController.uploadString(logoKml, '/var/www/html/kml/slave_$targetScreen.kml');
    _lastUpdatedKmlPath = '/var/www/html/kml/slave_$targetScreen.kml';
    await refreshView(screen: targetScreen);
  }

  Future<void> clearLogoFromLeftScreen({int? logoScreenNumber}) async {
    if (!isConnected) throw Exception('Not connected to LG');

    screenAmount = _settingsController.lgRigsNum;
    final int targetScreen = logoScreenNumber ?? getLogoScreen();

    final blankKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document id="slave_$targetScreen">
  </Document>
</kml>''';

    await sendKMLToSlave(targetScreen, blankKml);
    await refreshView(screen: targetScreen);
  }

  Future<void> refreshView({int? screen}) async {
    if (!isConnected) throw Exception('Not connected to LG');

    final String? targetPath = screen != null
        ? '/var/www/html/kml/slave_$screen.kml'
        : _lastUpdatedKmlPath;

    if (targetPath != null) {
      await executeCommand('touch $targetPath');
    }

    await executeCommand('echo "" >> /var/www/html/kmls.txt');
    await query('exittour=false');
  }
}
