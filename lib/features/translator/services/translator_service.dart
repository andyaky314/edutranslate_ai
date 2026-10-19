import '../models/translation.dart';


class TranslatorService {

  Future<Translation> translate({
    required String text,
    required String from,
    required String to,
  }) async {

    await Future.delayed(
      const Duration(seconds: 1),
    );


    if (text.toLowerCase() == "beautiful") {

      return Translation(

        originalText: text,

        translatedText:
            to == "Chinese"
                ? "美丽 / 漂亮"
                : "Cantik / Indah",

        sourceLanguage: from,

        targetLanguage: to,


        pronunciation:
            "/ˈbjuːtɪfl/",


        partOfSpeech:
            "Adjective",


        englishMeaning:
            "Having qualities that give pleasure "
            "to the senses or mind.",


        studentExplanation:
            "Something that looks very nice "
            "or makes people feel happy.",


        malayMeaning:
            "Cantik / Indah",


        chineseMeaning:
            "美丽 / 漂亮",


        exampleSentence:
            "The garden has beautiful flowers.",
      );
    }


    return Translation(

      originalText: text,

      translatedText:
          "Demo translation",

      sourceLanguage: from,

      targetLanguage: to,


      studentExplanation:
          "AI explanation will appear here.",

    );
  }
}