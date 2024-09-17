import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.setIndex,
  });

  final void Function(int x) setIndex;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 168, 154, 10),
            ),
            child: Text(
              'Al-Azan',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Prayer Times'),
            onTap: () {
              Navigator.of(context).pop();
              setIndex(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Qibla'),
            onTap: () {
              Navigator.of(context).pop(); 
              setIndex(1);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
