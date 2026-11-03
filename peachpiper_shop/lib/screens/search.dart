import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../state.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final q = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreState>();
    final res = s.search(q.text);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: q,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search kurta sets, anarkali, colours…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(q.clear)),
            isDense: true,
          ),
        ),
      ),
      body: q.text.trim().isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Popular', style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final w in ['Kurta set', 'Anarkali', 'Co-ord', 'Cotton', 'Silk', 'Embroidered', 'Black', 'Pink', 'Blue'])
                  ActionChip(label: Text(w), onPressed: () => setState(() => q.text = w)),
              ]),
            ])
          : res.isEmpty
              ? const Center(child: Text('No styles found. Try another word.', style: TextStyle(color: muted)))
              : ProductGrid(res),
    );
  }
}
