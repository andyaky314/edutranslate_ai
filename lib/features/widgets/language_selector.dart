import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final String title;
  final String language;
  final List<String> languages;
  final ValueChanged<String> onChanged;

  const LanguageSelector({
    super.key,
    required this.title,
    required this.language,
    required this.languages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        initialValue: language,
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          filled: true,
        ),
        items: languages
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}