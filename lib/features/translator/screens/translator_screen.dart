import 'package:flutter/material.dart';

import '../models/translation.dart';
import '../services/translator_service.dart';
import '../widgets/language_selector.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TranslatorService service = TranslatorService();
  final TextEditingController controller = TextEditingController();

  Translation? result;

  bool loading = false;

  String sourceLanguage = "English";
  String targetLanguage = "Bahasa Melayu";

  final languages = ["English", "Bahasa Melayu", "Chinese"];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void swapLanguage() {
    setState(() {
      final temp = sourceLanguage;
      sourceLanguage = targetLanguage;
      targetLanguage = temp;
    });
  }

  Future<void> translateText() async {
    if (controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      loading = true;
    });

    final translation = await service.translate(
      text: controller.text,
      from: sourceLanguage,
      to: targetLanguage,
    );

    setState(() {
      result = translation;
      loading = false;
    });
  }

  void clearText() {
    controller.clear();

    setState(() {
      result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Translator")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [
            const Text(
              "Translate",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Language selection
            Row(
              children: [
                LanguageSelector(
                  title: "From",
                  language: sourceLanguage,
                  languages: languages,
                  onChanged: (value) {
                    setState(() {
                      sourceLanguage = value;
                    });
                  },
                ),

                const SizedBox(width: 12),

                LanguageSelector(
                  title: "To",
                  language: targetLanguage,
                  languages: languages,
                  onChanged: (value) {
                    setState(() {
                      targetLanguage = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Swap button
            Center(
              child: FloatingActionButton.small(
                onPressed: swapLanguage,
                child: const Icon(Icons.swap_horiz),
              ),
            ),

            const SizedBox(height: 20),

            // Input area
            TextField(
              controller: controller,
              maxLines: 6,

              decoration: InputDecoration(
                hintText: "Type your text here...",

                border: const OutlineInputBorder(),

                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),

                  onPressed: clearText,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Translate button
            FilledButton.icon(
              onPressed: translateText,

              icon: const Icon(Icons.translate),

              label: const Text("Translate"),
            ),

            const SizedBox(height: 30),

            // Result card
Card(
  elevation: 1,

  child: Padding(
    padding: const EdgeInsets.all(16),

    child: loading
        ? const Center(
            child: CircularProgressIndicator(),
          )

        : result == null

            ? const Text(
                "Translation result will appear here.",
              )

            : Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    result!.translatedText,

                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "🔊 ${result!.pronunciation ?? ""}",
                  ),

                  const Divider(),

                  const Text(
                    "Word Type",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.partOfSpeech ?? "",
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Oxford Meaning",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.englishMeaning ?? "",
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Student Explanation",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.studentExplanation ?? "",
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Bahasa Melayu (DBP)",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.malayMeaning ?? "",
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Chinese",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.chineseMeaning ?? "",
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Example",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    result!.exampleSentence ?? "",
                  ),
                ],
              ),
  ),
),
          ],
        ),
      ),
    );
  }
}
