import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';
import 'category.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final q = TextEditingController();

  void _set(String t) {
    q.text = t;
    q.selection = TextSelection.collapsed(offset: t.length);
    context.read<RecentState>().searched(t);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final recent = context.watch<RecentState>();
    final res = s.search(q.text);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (t) => recent.searched(t),
            style: sans(15),
            decoration: InputDecoration(
              hintText: 'Search kurta sets, anarkali, colours…',
              prefixIcon: const Icon(Icons.search, color: wine),
              suffixIcon: q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(q.clear)),
              isDense: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: q.text.trim().isEmpty
          ? ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 24), children: [
              if (recent.searches.isNotEmpty) ...[
                Row(children: [
                  Text('RECENT', style: kicker()),
                  const Spacer(),
                  GestureDetector(onTap: recent.clearSearches, child: Text('CLEAR', style: kicker(color: muted, size: 10))),
                ]),
                const SizedBox(height: 8),
                for (final t in recent.searches)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.history, color: muted, size: 20),
                    title: Text(t, style: sans(14.5)),
                    onTap: () => _set(t),
                  ),
                const SizedBox(height: 18),
              ],
              Text('TRENDING', style: kicker()),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final w in ['Kurta set', 'Anarkali', 'Co-ord', 'Cotton', 'Silk', 'Embroidered', 'Festive', 'Office wear'])
                  ActionChip(label: Text(w), onPressed: () => _set(w)),
              ]),
              const SizedBox(height: 26),
              Text('CATEGORIES', style: kicker()),
              const SizedBox(height: 6),
              for (final c in s.categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.name, style: serif(21)),
                  trailing: const Icon(Icons.chevron_right, color: muted),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen(c.id, c.name))),
                ),
            ])
          : res.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('No styles found', style: serif(26)),
                    const SizedBox(height: 6),
                    Text('Try another word, like "cotton" or "pink".', style: sans(14, color: muted)),
                  ]),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(alignment: Alignment.centerLeft, child: Text('${res.length} STYLES', style: kicker(color: muted, size: 10))),
                  ),
                  Expanded(child: ProductGrid(res)),
                ]),
    );
  }
}
