import 'package:flutter/material.dart';

import '../app/brand.dart';
import '../app/store.dart';
import '../app/theme.dart';

/// Roster board. A grid of position groups, each holding a depth chart —
/// the whole squad is one screen, not a list you scroll for ever.
class ProductApp extends StatefulWidget {
  const ProductApp({super.key});

  @override
  State<ProductApp> createState() => _ProductAppState();
}

class _Group {
  final String id;
  final String label;
  final String name;
  const _Group(this.id, this.label, this.name);
}

const _groups = <_Group>[
  _Group('qb', 'QB', 'Quarterback'),
  _Group('rb', 'RB', 'Running Back'),
  _Group('wr', 'WR', 'Wide Receiver'),
  _Group('te', 'TE', 'Tight End'),
  _Group('ol', 'OL', 'Offensive Line'),
  _Group('dl', 'DL', 'Defensive Line'),
  _Group('lb', 'LB', 'Linebacker'),
  _Group('db', 'DB', 'Defensive Back'),
  _Group('st', 'ST', 'Special Teams'),
];

class _ProductAppState extends State<ProductApp> {
  static const _kPrefix = 'rb_';

  final Map<String, List<String>> _depth = {};
  bool _loading = true;
  String? _openGroup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final g in _groups) {
      final rows = await Store.getRecords('$_kPrefix${g.id}');
      final names = <String>[];
      for (final r in rows) {
        final n = r['name'];
        if (n is String && n.trim().isNotEmpty) names.add(n.trim());
      }
      _depth[g.id] = names;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _persist(String groupId) async {
    await Store.setRecords('$_kPrefix$groupId', [
      for (final n in _depth[groupId] ?? const <String>[]) {'name': n},
    ]);
  }

  Future<void> _addPlayer(_Group g) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Add to ${g.label}', style: AppTheme.display(18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Player name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (saved != true || name.isEmpty) return;

    setState(() => _depth[g.id] = [...?_depth[g.id], name]);
    await _persist(g.id);
  }

  Future<void> _remove(_Group g, int index) async {
    final list = [...?_depth[g.id]];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setState(() => _depth[g.id] = list);
    await _persist(g.id);
  }

  /// Подъём на строку вверх: глубина состава задаётся порядком, а не полем.
  Future<void> _promote(_Group g, int index) async {
    final list = [...?_depth[g.id]];
    if (index <= 0 || index >= list.length) return;
    final tmp = list[index - 1];
    list[index - 1] = list[index];
    list[index] = tmp;
    setState(() => _depth[g.id] = list);
    await _persist(g.id);
  }

  int get _total =>
      _depth.values.fold(0, (s, list) => s + list.length);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(child: CircularProgressIndicator(color: cAccent)),
      );
    }

    final open = _openGroup;
    final openGroup = open == null
        ? null
        : _groups.firstWhere((g) => g.id == open, orElse: () => _groups.first);

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: openGroup == null ? _grid() : _groupView(openGroup),
      ),
    );
  }

  Widget _grid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kProductTitle, style: AppTheme.display(24)),
              Text(
                '$_total player${_total == 1 ? '' : 's'} on the board',
                style: AppTheme.text(13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _groups.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Фиксированная высота, а не пропорция: на узком экране
              // ячейка по aspectRatio становится слишком низкой
              mainAxisExtent: 118,
            ),
            itemBuilder: (context, i) => _tile(_groups[i]),
          ),
        ),
      ],
    );
  }

  Widget _tile(_Group g) {
    final count = _depth[g.id]?.length ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _openGroup = g.id),
        borderRadius: AppTheme.radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.panel(
            accented: count > 0,
            outlined: count > 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                g.label,
                style: TextStyle(
                  fontFamily: kDisplayFont,
                  fontSize: 24,
                  color: count > 0 ? cAlt : AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                g.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.text(
                  11.5,
                  color: AppTheme.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count',
                style: AppTheme.text(
                  12,
                  weight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupView(_Group g) {
    final list = _depth[g.id] ?? const <String>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _openGroup = null),
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.textSecondary,
              ),
              Expanded(
                child: Text(
                  g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(20),
                ),
              ),
              IconButton(
                onPressed: () => _addPlayer(g),
                icon: const Icon(Icons.person_add_alt_rounded),
                color: cAlt,
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'No players in this group yet.',
                      textAlign: TextAlign.center,
                      style: AppTheme.text(
                        14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: AppTheme.panel(accented: i == 0),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0
                                ? cAccent
                                : cAlt.withValues(alpha: 0.16),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: AppTheme.text(
                              12.5,
                              weight: FontWeight.w700,
                              color: i == 0 ? AppTheme.onAccent : cAlt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            list[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.text(
                              15,
                              weight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: i == 0 ? null : () => _promote(g, i),
                          icon: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 20,
                          ),
                          color: cAlt,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () => _remove(g, i),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          color: AppTheme.textMuted,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
