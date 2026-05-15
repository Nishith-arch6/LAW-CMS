import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/search_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/theme/app_theme.dart';

const _recentBox = 'recent_searches';
const _maxRecent = 10;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  late Box _recentHiveBox;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _initRecent();
  }

  Future<void> _initRecent() async {
    _recentHiveBox = await Hive.openBox(_recentBox);
    setState(() {
      _recentSearches = _recentHiveBox.get('queries', defaultValue: <String>[]).cast<String>().reversed.toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    _recentHiveBox.close();
    super.dispose();
  }

  void _search(String q) {
    if (q.trim().isEmpty) return;
    ref.read(searchProvider.notifier).search(q);
    _saveRecent(q);
  }

  void _saveRecent(String q) {
    final list = <String>[..._recentSearches];
    list.remove(q);
    list.insert(0, q);
    if (list.length > _maxRecent) list.removeLast();
    _recentHiveBox.put('queries', list.reversed.toList());
    setState(() => _recentSearches = list);
  }

  void _clearRecent() {
    _recentHiveBox.delete('queries');
    setState(() => _recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search cases, documents, clients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
              ),
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(height: 8),
          if (state.query.isNotEmpty)
            TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: 'Cases (${state.caseResults.length})'),
                Tab(text: 'Documents (${state.docResults.length})'),
              ],
            ),
          Expanded(
            child: state.query.isEmpty
                ? _recentSearches.isEmpty
                    ? const EmptyState(icon: Icons.search, title: 'Search your cases & documents')
                    : _RecentSearches(
                        searches: _recentSearches,
                        onTap: (q) {
                          _searchCtrl.text = q;
                          _search(q);
                        },
                        onClear: _clearRecent,
                      )
                : state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.isEmpty
                        ? const EmptyState(icon: Icons.search_off, title: 'No results found')
                        : TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _ResultsList(results: state.caseResults, type: 'case'),
                              _ResultsList(results: state.docResults, type: 'document'),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  const _RecentSearches({
    required this.searches,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Searches', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey)),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searches.length,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(searches[i]),
              onTap: () => onTap(searches[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<SearchResult> results;
  final String type;

  const _ResultsList({required this.results, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final r = results[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              if (type == 'case') context.push('/cases/${r.id}');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type == 'case' ? Icons.folder : Icons.description,
                      color: AppColors.primary, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        if (r.subtitle != null)
                          Text(r.subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        if (r.snippet != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(r.snippet!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
