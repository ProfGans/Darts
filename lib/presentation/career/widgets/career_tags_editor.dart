import 'package:flutter/material.dart';

import 'career_editor_section_card.dart';

class CareerTagsEditor extends StatelessWidget {
  const CareerTagsEditor({
    super.key,
    required this.isEditingCareerTag,
    required this.careerTagCount,
    required this.tagDefinitionSection,
    required this.seasonRulesSection,
    required this.existingTagsSection,
  });

  final bool isEditingCareerTag;
  final int careerTagCount;
  final Widget tagDefinitionSection;
  final Widget seasonRulesSection;
  final Widget existingTagsSection;

  @override
  Widget build(BuildContext context) {
    return CareerEditorSectionCard(
      title: isEditingCareerTag
          ? 'Karriere-Tag bearbeiten'
          : 'Karriere-Tag-Editor',
      subtitle: '$careerTagCount Karriere-Tags',
      children: <Widget>[
        tagDefinitionSection,
        const SizedBox(height: 16),
        seasonRulesSection,
        const SizedBox(height: 16),
        existingTagsSection,
      ],
    );
  }
}
