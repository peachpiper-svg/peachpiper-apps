import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';

const chName = {'wa': 'WhatsApp', 'ig': 'Instagram', 'fb': 'Facebook', 'web': 'Website', 'igc': 'IG comment', 'fbc': 'FB comment'};
const chColor = {'wa': Color(0xFF25D366), 'ig': Color(0xFFC13584), 'fb': Color(0xFF1877F2), 'web': Color(0xFF8B5E3C), 'igc': Color(0xFFE1306C), 'fbc': Color(0xFF4267B2)};

Widget chip(String ch) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: chColor[ch] ?? muted, borderRadius: BorderRadius.circular(999)),
      child: Text(chName[ch] ?? ch, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );

String who(Map t) => (t['name'] ?? '').toString().isNotEmpty
    ? t['name'].toString()
    : t['channel'] == 'wa'
        ? '+91 ${t['contact']}'
        : t['channel'] == 'web'
            ? t['contact'].toString()
            : 'Customer ${t['contact'].toString().substring(t['contact'].toString().length > 4 ? t['contact'].toString().length - 4 : 0)}';

class InboxScreen extends StatefulWidget {
  final String filter;
  const InboxScreen({super.key, this.filter = ''});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late String f = widget.filter;
  String ch = '';
  List<Map<String, dynamic>> threads = [];
  bool busy = true;

  Future<void> load() async {
    try {
      final r = await Api.I.get('inbox.threads', {'f': f, 'ch': ch});
      threads = ((r['threads'] as List?) ?? const []).map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [['', '', 'All'], ['', 'human', 'Needs you'], ['', 'unread', 'Unread'], ['wa', '', 'WhatsApp'], ['ig', '', 'Instagram'], ['fb', '', 'Facebook'], ['igc', '', 'IG comments']];
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: Column(children: [
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                    label: Text(t[2]),
                    selected: ch == t[0] && f == t[1],
                    onSelected: (_) {
                      ch = t[0];
                      f = t[1];
                      load();
                    }),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: busy
                ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator(color: wine))])
                : ListView.separated(
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = threads[i];
                      final unread = int.tryParse('${t['unread']}') ?? 0;
                      return ListTile(
                        tileColor: Colors.white,
                        title: Row(children: [chip(t['channel'].toString()), const SizedBox(width: 6), Expanded(child: Text(who(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)))]),
                        subtitle: Text('${t['last_dir'] == 'out' ? 'Replied: ' : ''}${t['last_text'] ?? ''}\n${when((t['last_at'] ?? '').toString())}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: unread > 0 ? CircleAvatar(radius: 11, backgroundColor: const Color(0xFF25D366), child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white))) : ('${t['needs_human']}' == '1' ? const Icon(Icons.flag, color: attn) : null),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadScreen(t['channel'].toString(), t['contact'].toString(), who(t))));
                          load();
                        },
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  final String ch, contact, title;
  const ThreadScreen(this.ch, this.contact, this.title, {super.key});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  List msgs = [];
  Map<String, dynamic> thread = {};
  final text = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  Future<void> load() async {
    try {
      final r = await Api.I.get('inbox.thread', {'ch': widget.ch, 'c': widget.contact});
      setState(() {
        msgs = (r['messages'] as List?) ?? [];
        thread = Map<String, dynamic>.from(r['thread'] ?? {});
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> send() async {
    if (text.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await Api.I.post('inbox.send', {'ch': widget.ch, 'c': widget.contact, 'text': text.text.trim()});
      text.clear();
      await load();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> aiNow() async {
    try {
      await Api.I.post('inbox.ai_now', {'ch': widget.ch, 'c': widget.contact});
      await load();
    } catch (e) {
      if (mounted) showErr(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [chip(widget.ch), const SizedBox(width: 8), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]), actions: [
        IconButton(tooltip: 'Reply with AI', icon: const Icon(Icons.auto_awesome), onPressed: aiNow),
        if ('${thread['needs_human']}' == '1')
          IconButton(
              tooltip: 'Done',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () async {
                await Api.I.post('inbox.flag', {'ch': widget.ch, 'c': widget.contact, 'needs_human': 0});
                load();
              }),
      ]),
      body: Column(children: [
        Expanded(
          child: Container(
            color: const Color(0xFFEFE7DE),
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(10),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final mine = m['dir'] != 'in';
                final auto = m['kind'] == 'ai' || m['kind'] == 'auto';
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    decoration: BoxDecoration(color: mine ? (auto ? const Color(0xFFE7F0FD) : const Color(0xFFDCF8C6)) : Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Align(alignment: Alignment.centerLeft, child: Text((m['text'] ?? '').toString())),
                      Text('${when((m['at'] ?? '').toString())}${auto ? ' · ${m['kind'] == 'ai' ? 'AI' : 'auto'}' : ''}', style: const TextStyle(fontSize: 10.5, color: muted)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: text, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Type a reply', isDense: true))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: wine)),
            ]),
          ),
        ),
      ]),
    );
  }
}
