import 'package:flutter/material.dart';

import 'decrypt_tab.dart';
import 'encrypt_tab.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قفل الروابط'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.lock_outline), text: 'تشفير'),
              Tab(icon: Icon(Icons.lock_open_outlined), text: 'فك التشفير'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              EncryptTab(),
              DecryptTab(),
            ],
          ),
        ),
      ),
    );
  }
}
