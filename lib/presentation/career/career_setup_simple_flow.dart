part of 'career_setup_screen.dart';

extension _CareerSetupSimpleFlow on _CareerSetupScreenState {
  Widget _buildTemplateSelectionCard(BuildContext context) {
    final templates = _templateRepository.templates;
    final selectedTemplate = _selectedTemplate();
    final isBuiltInTemplate = selectedTemplate != null &&
        _templateRepository.isBuiltInTemplate(selectedTemplate.id);
    final canEditTemplate = selectedTemplate != null;
    final subtitle = selectedTemplate == null
        ? 'Waehle eine Vorlage fuer den Karriere-Start aus.'
        : '${selectedTemplate.calendar.length} Turniere | ${selectedTemplate.rankings.length} Ranglisten';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Vorlage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            ),
            if (templates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>('grundlagen-template-$_selectedTemplateId'),
                initialValue: _selectedTemplateId,
                decoration: const InputDecoration(labelText: 'Aktive Vorlage'),
                items: templates
                    .map(
                      (template) => DropdownMenuItem<String?>(
                        value: template.id,
                        child: Text(template.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _updateState(() {
                    _selectedTemplateId = value;
                    _simpleQuickTournamentGenerationEnabled = false;
                  });
                },
              ),
              if (selectedTemplate != null) ...<Widget>[
                const SizedBox(height: 12),
                if (canEditTemplate)
                  FilledButton.tonalIcon(
                    onPressed: () => _beginEditTemplate(selectedTemplate),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(
                      isBuiltInTemplate
                          ? 'Als Kopie bearbeiten'
                          : 'Ausgewaehlte Vorlage bearbeiten',
                    ),
                  )
                else
                  Text(
                    'Diese App-Vorlage ist fest eingebaut und kann hier nicht bearbeitet werden.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _setSimpleUseTemplate(bool value) {
    _updateState(() {
      _simpleUseTemplate = value;
      if (value) {
        _simpleQuickTournamentGenerationEnabled = false;
      } else {
        _selectedTemplateId = null;
        _simpleQuickTournamentGenerationEnabled =
            _simpleCreationPath == _SimpleCreationPath.simple;
      }
    });
  }

  void _setSimpleCreationPath(_SimpleCreationPath path) {
    _updateState(() {
      _simpleCreationPath = path;
      if (!_simpleUseTemplate) {
        _simpleQuickTournamentGenerationEnabled =
            path == _SimpleCreationPath.simple;
      }
    });
  }

  Widget _buildSimpleCreationDecisionCard(BuildContext context) {
    return _buildWizardSectionCard(
      context,
      title: 'Karriere-Start',
      subtitle:
          'Lege zuerst fest, ob du mit Trainingsmodus spielst, ob du eine Vorlage verwendest und welcher Erstellungsweg danach folgt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _simpleTrainingModeEnabled,
            onChanged: (value) {
              _updateState(() {
                _simpleTrainingModeEnabled = value;
                if (!value) {
                  _simpleTemplateTrainingOverrides.clear();
                  _selectedTrainingPoolTagName = null;
                  _trainingMinAverageController.clear();
                  _trainingMaxAverageController.clear();
                }
              });
            },
            title: const Text('Mit Trainingsmodus spielen'),
            subtitle: const Text(
              'Damit kannst du die Average-Spanne deines Start-Kaders vor der Karriere festlegen.',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _simpleUseTemplate,
            onChanged: _setSimpleUseTemplate,
            title: const Text('Vorlage verwenden'),
            subtitle: const Text(
              'Mit Vorlage startest du aus einem vorhandenen Karriere-Geruest. Ohne Vorlage entscheidest du dich im naechsten Schritt fuer Quick oder Expertenmodus.',
            ),
          ),
          if (!_simpleUseTemplate) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Erstellungsweg',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Einfache Erstellung'),
                  selected: _simpleCreationPath == _SimpleCreationPath.simple,
                  onSelected: (_) =>
                      _setSimpleCreationPath(_SimpleCreationPath.simple),
                ),
                ChoiceChip(
                  label: const Text('Experten-Erstellung'),
                  selected: _simpleCreationPath == _SimpleCreationPath.expert,
                  onSelected: (_) =>
                      _setSimpleCreationPath(_SimpleCreationPath.expert),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _simpleCreationPath == _SimpleCreationPath.simple
                  ? 'Die einfache Erstellung fuehrt dich in die Quick-Tour und den kompakten Karriere-Start.'
                  : 'Die Experten-Erstellung fuehrt dich direkt in den vollstaendigen Karriere-Editor.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleQuickTournamentCard(
    BuildContext context,
    CareerTemplate? template,
  ) {
    final selectedFormats = _effectiveSimpleQuickFormats();
    final selectedPoolCount = _templateCreationPoolPlayers(template).length;
    final rosterSize = _effectiveSimpleTargetRosterSize(selectedPoolCount);
    final availableBlueprints = _availableSimpleQuickTourBlueprints();
    final selectedBlueprints = availableBlueprints
        .where((entry) => _simpleQuickSelectedBlueprintIds.contains(entry.id))
        .toList();
    final addableBlueprints = availableBlueprints
        .where((entry) => !_simpleQuickSelectedBlueprintIds.contains(entry.id))
        .toList();
    final desiredTournamentCount = _desiredSimpleQuickTournamentCount();
    final plannedTournamentCount = _currentSimpleQuickTournamentCount();

    return _buildWizardSectionCard(
      context,
      title: 'Quick-Turniererstellung',
      subtitle:
          'Baue hier deine eigene Quick-Tour aus frei hinzugefuegten Turnierbausteinen auf.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Dieser Schritt ist aktiv, weil du dich oben fuer die einfache Erstellung ohne Vorlage entschieden hast.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Aktueller Ziel-Kader: $rosterSize Spieler',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _simpleQuickSeasonTournamentCountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Turniere pro Saison',
                    helperText:
                        'Gib an, wie viele Turniere die Quick-Saison insgesamt enthalten soll.',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: availableBlueprints.isEmpty ||
                              desiredTournamentCount <= 0
                          ? null
                          : _autoBuildSimpleQuickSeasonPlan,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Automatisch erstellen'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plannedTournamentCount <= 0
                            ? 'Aktuell sind noch keine Quick-Turniere verplant.'
                            : '$plannedTournamentCount Quick-Turniere sind aktuell eingeplant.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF556372),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Formate',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TournamentFormat.values.map((format) {
                    final selected = selectedFormats.contains(format);
                    return FilterChip(
                      label: Text(_tournamentFormatLabel(format)),
                      selected: selected,
                      onSelected: (_) {
                        _updateState(() {
                          if (selected) {
                            if (_simpleQuickFormats.length > 1) {
                              _simpleQuickFormats.remove(format);
                            }
                          } else {
                            _simpleQuickFormats.add(format);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Modi',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilterChip(
                      label: const Text('Turnierserien'),
                      selected: _simpleQuickIncludeSeries,
                      onSelected: (value) {
                        if (!value && !_simpleQuickIncludeStandalone) {
                          return;
                        }
                        _updateState(() => _simpleQuickIncludeSeries = value);
                      },
                    ),
                    FilterChip(
                      label: const Text('Einzelturniere'),
                      selected: _simpleQuickIncludeStandalone,
                      onSelected: (value) {
                        if (!value && !_simpleQuickIncludeSeries) {
                          return;
                        }
                        _updateState(() => _simpleQuickIncludeStandalone = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bausteine',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Material(
                      color: addableBlueprints.isEmpty
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: addableBlueprints.isEmpty
                            ? null
                            : () => _openSimpleQuickTournamentComposer(
                                  addableBlueprints,
                                  rosterSize: rosterSize,
                                ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          addableBlueprints.isEmpty
                              ? 'Mit den aktuellen Filtern sind keine weiteren Turnierarten verfuegbar.'
                              : 'Fuege neue Turniere hinzu und bearbeite sie anschliessend immer ueber dieselbe Quick-Turnier-Seite.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF556372),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Ausgewaehlte Tour-Bausteine',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (selectedBlueprints.isEmpty)
                  const Text(
                    'Fuege zuerst Tour-Bausteine hinzu. Die komplette Konfiguration erfolgt dann in der Quick-Turnier-Seite.',
                  )
                else
                  _buildSimpleQuickSelectedBlueprintList(
                    context,
                    selectedBlueprints: selectedBlueprints,
                    rosterSize: rosterSize,
                  ),
                const SizedBox(height: 6),
                Text(
                  template == null
                      ? 'Ohne Vorlage wird eine eigenstaendige Quick-Tour aufgebaut.'
                      : 'Mit Vorlage bleibt Quick deaktiviert, bis du die Vorlage abwaehlst.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF556372),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleQuickSelectedBlueprintList(
    BuildContext context, {
    required List<_SimpleQuickTourBlueprint> selectedBlueprints,
    required int rosterSize,
  }) {
    return Column(
      children: selectedBlueprints
          .map(
            (blueprint) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSimpleQuickSelectedBlueprintCard(
                context,
                blueprint: blueprint,
                rosterSize: rosterSize,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSimpleQuickSelectedBlueprintCard(
    BuildContext context, {
    required _SimpleQuickTourBlueprint blueprint,
    required int rosterSize,
  }) {
    final config = _simpleQuickTourConfigs[blueprint.id] ??
        _SimpleQuickTourTypeConfig(
          count: _defaultSimpleQuickCountForBlueprint(blueprint.id),
        );
    final effectiveFieldSize = config.fieldSizeOverride ??
        _quickFieldSizeForBlueprint(
          blueprint: blueprint,
          rosterSize: rosterSize,
        );
    final effectivePrizePool = config.prizePoolOverride ??
        _quickPrizePoolForFieldSize(
          blueprint: blueprint,
          fieldSize: effectiveFieldSize,
        );
    final displayName = (config.customName?.trim().isNotEmpty ?? false)
        ? config.customName!.trim()
        : blueprint.categoryName;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        blueprint.isSeries ? 'Serienformat' : 'Einzelturnier',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF556372),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F4F3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_tournamentFormatLabel(blueprint.format)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _buildQuickSummaryChip('Anzahl', '${config.count}'),
                _buildQuickSummaryChip('Teilnehmerfeld', '$effectiveFieldSize'),
                _buildQuickSummaryChip('Preisgeld', '$effectivePrizePool'),
                _buildQuickSummaryChip(
                  'Share',
                  config.prizeSplitPreset.label,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _editSimpleQuickTournamentBlueprint(
                    blueprint,
                    rosterSize: rosterSize,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Bearbeiten'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    _updateState(() {
                      _simpleQuickSelectedBlueprintIds.remove(blueprint.id);
                      _simpleQuickTourConfigs.remove(blueprint.id);
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Entfernen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _buildSimpleCreationIntroCard(BuildContext context) {
    final title = _simpleUseTemplate
        ? 'Vorlagen-Start'
        : (_simpleCreationPath == _SimpleCreationPath.simple
            ? 'Einfache Erstellung'
            : 'Experten-Erstellung');
    final description = _simpleUseTemplate
        ? 'Du startest aus einer Vorlage. Waehle jetzt das passende Karriere-Geruest und erstelle daraus deinen Laufbahn-Start.'
        : (_simpleCreationPath == _SimpleCreationPath.simple
            ? 'Du baust ohne Vorlage eine Quick-Tour auf und startest danach direkt in die Karriere.'
            : 'Du startest ohne Vorlage direkt in den vollstaendigen Karriere-Editor.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalTrainingModeCard(BuildContext context) {
    final selectedTemplate = _selectedTemplate();
    return _buildWizardSectionCard(
      context,
      title: 'Trainingsmodus',
      subtitle:
          'Dieser Schritt liegt bewusst ueber allen Editoren, weil er den Start-Kader und damit die spaetere Karrierequalitaet festlegt.',
      child: _buildSimpleTrainingModeSection(selectedTemplate),
    );
  }

  Widget _buildSimpleRosterSizeSection(BuildContext context) {
    final selectedTemplate = _selectedTemplate();
    final selectedPoolCount = _templateCreationPoolPlayers(selectedTemplate).length;
    final targetRosterSize = _effectiveSimpleTargetRosterSize(selectedPoolCount);
    final generatedCount = max(0, targetRosterSize - selectedPoolCount);
    return _buildWizardSectionCard(
      context,
      title: 'Kadergroesse',
      subtitle:
          'Lege frueh fest, wie gross der Karriere-Kader insgesamt sein soll. Fehlende Plaetze werden mit schwaecheren Spielern aufgefuellt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _simpleTargetRosterSizeController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateState(() {}),
            decoration: const InputDecoration(
              labelText: 'Ziel-Kadergroesse',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            generatedCount <= 0
                ? 'Der aktuelle Kader ist bereits gross genug. Es werden keine Zusatzspieler erzeugt.'
                : '$generatedCount Zusatzspieler werden automatisch erzeugt und bewusst schwaecher als dein ausgewaehlter Kern gehalten.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStartSection(
    BuildContext context, {
    required CareerTemplate? selectedTemplate,
    required CareerTemplate? effectiveTemplate,
    required int selectedPoolCount,
    required int generatedCount,
    required int targetRosterSize,
    required bool canCreate,
  }) {
    final summary = selectedTemplate == null
        ? (_simpleQuickTournamentGenerationEnabled
            ? '$selectedPoolCount ausgewaehlte Spieler. ${generatedCount <= 0 ? 'Der aktuelle Kader ist bereits gross genug.' : '$generatedCount Zusatzspieler und bis zu $targetRosterSize Kaderplaetze sind vorbereitet.'} ${effectiveTemplate == null ? 'Noch keine Quick-Tour aktiv.' : '${effectiveTemplate.calendar.length} Quick-Tour-Eintraege sind vorbereitet.'}'
            : 'Waehle zuerst eine Vorlage oder aktiviere die Quick-Erstellung.')
        : '$selectedPoolCount ausgewaehlte Spieler. ${generatedCount <= 0 ? 'Der aktuelle Kader ist bereits gross genug.' : '$generatedCount Zusatzspieler und bis zu $targetRosterSize Kaderplaetze sind vorbereitet.'}';
    return _buildWizardSectionCard(
      context,
      title: 'Start',
      subtitle:
          'Hier pruefst du den aktuellen Stand und startest die Karriere-Erstellung.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canCreate ? _createSimpleCareerFromTemplate : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Einfache Karriere erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectExpertCreationSection(
    BuildContext context, {
    required List<CareerDefinition> careers,
    required CareerDefinition? activeCareer,
    required List<CareerTemplate> templates,
    required List<PlayerProfile> players,
  }) {
    return _buildWizardSectionCard(
      context,
      title: 'Experten-Erstellung',
      subtitle:
          'Du hast dich fuer die freie Experten-Erstellung ohne Vorlage entschieden. Hier bearbeitest du Karriere, Regeln, Ranglisten und Kalender direkt.',
      child: _buildCareerCard(
        context,
        careers: careers,
        activeCareer: activeCareer,
        templates: templates,
        players: players,
        showInitialSetupOptions: false,
      ),
    );
  }

  Widget _buildSimpleCreationCard(BuildContext context) {
    final selectedTemplate = _selectedTemplate();
    final effectiveTemplate = _simpleUseTemplate
        ? selectedTemplate
        : (_simpleCreationPath == _SimpleCreationPath.simple
            ? _effectiveSimpleCreationTemplate()
            : null);
    final selectedPoolCount = _templateCreationPoolPlayers(selectedTemplate).length;
    final targetRosterSize = _effectiveSimpleTargetRosterSize(selectedPoolCount);
    final generatedCount = max(0, targetRosterSize - selectedPoolCount);
    final canCreate = effectiveTemplate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSimpleCreationIntroCard(context),
        const SizedBox(height: 16),
        if (_simpleUseTemplate) ...<Widget>[
          _buildTemplateSelectionCard(context),
          const SizedBox(height: 16),
        ] else if (_simpleCreationPath == _SimpleCreationPath.simple) ...<Widget>[
          _buildSimpleQuickTournamentCard(context, selectedTemplate),
          const SizedBox(height: 16),
        ],
        _buildSimpleStartSection(
          context,
          selectedTemplate: selectedTemplate,
          effectiveTemplate: effectiveTemplate,
          selectedPoolCount: selectedPoolCount,
          generatedCount: generatedCount,
          targetRosterSize: targetRosterSize,
          canCreate: canCreate,
        ),
      ],
    );
  }

  Widget _buildUnifiedCreationCard(
    BuildContext context, {
    required List<CareerDefinition> careers,
    required CareerDefinition? activeCareer,
    required List<CareerTemplate> templates,
    required List<PlayerProfile> players,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSimpleCreationDecisionCard(context),
        const SizedBox(height: 16),
        if (_simpleTrainingModeEnabled) ...<Widget>[
          _buildGlobalTrainingModeCard(context),
          const SizedBox(height: 16),
        ],
        _buildTemplatePoolSelector(
          context,
          labelText: 'Karriere-Kader',
        ),
        const SizedBox(height: 16),
        _buildSimpleRosterSizeSection(context),
        const SizedBox(height: 16),
        if (_simpleUseTemplate ||
            _simpleCreationPath == _SimpleCreationPath.simple)
          _buildSimpleCreationCard(context)
        else
          _buildDirectExpertCreationSection(
            context,
            careers: careers,
            activeCareer: activeCareer,
            templates: templates,
            players: players,
          ),
      ],
    );
  }
}
