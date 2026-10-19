import 'package:flutter/material.dart';
import '../features/translator/screens/translator_screen.dart';

class EduTranslateApp extends StatelessWidget {
  const EduTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTranslate AI',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xffF5F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),

      home: const TranslatorScreen(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _feature(
      IconData icon,
      String title,
      String subtitle,
      Color color,
      ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("EduTranslate AI"),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [

          const SizedBox(height: 10),

          const Text(
            "AI Language Companion",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Helping Malaysian SJKC students master English, Bahasa Melayu and Chinese.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xff2196F3),
                  Color(0xff00BCD4),
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  "Welcome 👋",
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  "Start learning smarter with AI.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  "Translate • Learn • Practise",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          _feature(
            Icons.translate,
            "AI Translator",
            "Translate between English, BM and Chinese",
            Colors.blue,
          ),

          _feature(
            Icons.menu_book,
            "Vocabulary Builder",
            "Save and review vocabulary",
            Colors.green,
          ),

          _feature(
            Icons.school,
            "Grammar Coach",
            "Learn grammar with AI",
            Colors.orange,
          ),

          _feature(
            Icons.camera_alt,
            "Homework Assistant",
            "Scan homework and learn",
            Colors.purple,
          ),

          _feature(
            Icons.record_voice_over,
            "Pronunciation Coach",
            "Improve speaking confidence",
            Colors.red,
          ),
        ],
      ),
    );
  }
}