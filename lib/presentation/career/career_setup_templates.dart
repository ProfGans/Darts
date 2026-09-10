part of 'career_setup_screen.dart';

extension _CareerSetupTemplates on _CareerSetupScreenState {
  Widget _buildTemplatesCard(BuildContext context, CareerDefinition career) {
    return _buildExpandableSection(
      context: context,
      title: 'Vorlagen',
      subtitle: '${_templateRepository.templates.length} gespeichert',
      children: <Widget>[
        if (_editingTemplateId != null) ...<Widget>[
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Du bearbeitest gerade eine bestehende Vorlage. Mit dem Button unten aktualisierst du genau diese Vorlage.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _templateNameController,
          decoration: const InputDecoration(labelText: 'Vorlagenname'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            if (_editingTemplateId != null) {
              _updateEditedTemplateFromCareer(career);
              return;
            }
            _saveCurrentCareerAsTemplate(career);
          },
          icon: Icon(
            _editingTemplateId != null
                ? Icons.edit_note_rounded
                : Icons.bookmark_add,
          ),
          label: Text(
            _editingTemplateId != null
                ? 'Vorlage aktualisieren'
                : 'Aktuelle Planung als Vorlage speichern',
          ),
        ),
        if (_templateRepository.templates.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ..._templateRepository.templates.map((template) {
            final isBuiltIn = _templateRepository.isBuiltInTemplate(template.id);
            final isEditing = _editingTemplateId == template.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(template.name),
              subtitle: Text(
                '${template.calendar.length} Turniere | ${template.rankings.length} Ranglisten | Pool wird beim Erstellen gewaehlt',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (isBuiltIn)
                    const Chip(label: Text('App'))
                  else ...<Widget>[
                    IconButton(
                      onPressed: () => _beginEditTemplate(template),
                      icon: Icon(
                        isEditing ? Icons.edit_rounded : Icons.edit_outlined,
                      ),
                      tooltip: 'Vorlage bearbeiten',
                    ),
                    IconButton(
                      onPressed: () {
                        _templateRepository.deleteTemplate(template.id);
                        _updateState(() {});
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  void _saveCurrentCareerAsTemplate(CareerDefinition career) {
    _templateRepository.saveTemplate(
      name: _templateNameController.text.isEmpty
          ? '${career.name} Vorlage'
          : _templateNameController.text,
      careerTagDefinitions:
          List<CareerTagDefinition>.from(career.careerTagDefinitions),
      seasonTagRules: List<CareerSeasonTagRule>.from(career.seasonTagRules),
      rankings: List<CareerRankingDefinition>.from(career.rankings),
      calendar: List<CareerCalendarItem>.from(career.currentSeason.calendar),
    );
    _templateNameController.clear();
    _updateState(() {});
  }

  Future<void> _beginEditTemplate(CareerTemplate template) async {
    final editableTemplate = _templateRepository.isBuiltInTemplate(template.id)
        ? _templateRepository.duplicateTemplate(source: template)
        : template;
    final draftTemplateName = editableTemplate.name;
    final draftTemplateId = editableTemplate.id;
    final draftPlayers = _templateCreationPoolPlayers(editableTemplate);
    await _runBusyAction(
      message: 'Vorlage wird zum Bearbeiten geladen...',
      action: () async {
        await Future<void>.delayed(Duration.zero);
        _repository.createCareerFromTemplate(
          name: draftTemplateName,
          template: editableTemplate,
          databasePlayers: draftPlayers,
          participantMode: _participantMode,
          playerProfileId: _participantMode == CareerParticipantMode.withHuman
              ? _selectedPlayerProfileId
              : null,
          replaceWeakestPlayerWithHuman:
              _participantMode == CareerParticipantMode.withHuman &&
                  _replaceWeakestPlayerWithHuman,
        );
      },
    );
    final draftCareer = _repository.activeCareer;
    if (!mounted || draftCareer == null) {
      return;
    }
    _updateState(() {
      _editingTemplateId = draftTemplateId;
      _editingTemplateDraftCareerId = draftCareer.id;
      _templateNameController.text = draftTemplateName;
      _setSetupStep(_CareerSetupStep.grundlagen);
    });
  }

  void _updateEditedTemplateFromCareer(CareerDefinition career) {
    final templateId = _editingTemplateId;
    if (templateId == null) {
      return;
    }
    _templateRepository.updateTemplate(
      templateId: templateId,
      name: _templateNameController.text.isEmpty
          ? career.name
          : _templateNameController.text,
      careerTagDefinitions:
          List<CareerTagDefinition>.from(career.careerTagDefinitions),
      seasonTagRules: List<CareerSeasonTagRule>.from(career.seasonTagRules),
      rankings: List<CareerRankingDefinition>.from(career.rankings),
      calendar: List<CareerCalendarItem>.from(career.currentSeason.calendar),
    );
    _updateState(() {
      _editingTemplateId = null;
      _editingTemplateDraftCareerId = null;
      _templateNameController.clear();
    });
  }
}
