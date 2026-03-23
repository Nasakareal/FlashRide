import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static final String _BASE = AuthService.baseUrl;

  bool _loading = true;
  bool _submitting = false;

  String _token = '';
  String _nombre = 'Usuario';

  final TextEditingController _subjectCtl = TextEditingController();
  final TextEditingController _messageCtl = TextEditingController();

  List<Map<String, dynamic>> _tickets = [];

  Future<Map<String, String>> _authHeaders() async {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token') ?? '';
    _nombre = p.getString('name') ?? 'Usuario';

    await _loadTickets();
  }

  @override
  void dispose() {
    _subjectCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);

    try {
      final res = await http.get(
        Uri.parse('$_BASE/tickets'),
        headers: await _authHeaders(),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Soportamos 2 formatos comunes:
        // 1) Lista directa: [ {...}, {...} ]
        // 2) Objeto con "data": { "data": [ ... ] } o { "data": [ ... ] }
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is Map &&
            data['data'] is Map &&
            data['data']['data'] is List) {
          list = data['data']['data'];
        }

        _tickets = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      } else if (res.statusCode == 401) {
        _tickets = [];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sesión no válida. Inicia sesión de nuevo.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error al cargar tickets: ${res.statusCode} ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al cargar tickets: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _createTicket() async {
    final subject = _subjectCtl.text.trim();
    final message = _messageCtl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa asunto y mensaje.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final res = await http.post(
        Uri.parse('$_BASE/tickets'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'subject': subject,
          'message': message,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 200) {
        _subjectCtl.clear();
        _messageCtl.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket enviado a soporte ✅')),
        );

        await _loadTickets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No se pudo crear ticket: ${res.statusCode} ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al crear ticket: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _openTicketDetail(Map<String, dynamic> t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupportTicketDetailScreen(ticket: t)),
    );
    if (!mounted) return;
    await _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Soporte'),
          bottom: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.confirmation_number_outlined),
                  text: 'Mis tickets'),
              Tab(icon: Icon(Icons.add_comment_outlined), text: 'Nuevo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ticketsTab(),
            _newTicketTab(),
          ],
        ),
      ),
    );
  }

  Widget _ticketsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Hola $_nombre 👋\n\nAún no tienes tickets.\nCrea uno en la pestaña "Nuevo".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = _tickets[i];
          final id = t['id']?.toString() ?? '-';
          final subject =
              (t['subject'] ?? t['titulo'] ?? 'Sin asunto').toString();
          final status = (t['status'] ?? t['estado'] ?? 'abierto').toString();
          final last = (t['updated_at'] ?? t['created_at'] ?? '').toString();

          return Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent),
              title:
                  Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Ticket #$id · $status\n$last',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTicketDetail(t),
            ),
          );
        },
      ),
    );
  }

  Widget _newTicketTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _subjectCtl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Asunto',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _messageCtl,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                labelText: 'Describe el problema',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _createTicket,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Enviando…' : 'Enviar a soporte'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tip: incluye calle, colonia y qué estabas haciendo cuando falló.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class SupportTicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const SupportTicketDetailScreen({super.key, required this.ticket});

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen>
    with WidgetsBindingObserver {
  static final String _BASE = AuthService.baseUrl;

  bool _loading = true;
  bool _sending = false;

  String _token = '';
  Map<String, dynamic>? _ticket;

  final TextEditingController _replyCtl = TextEditingController();

  Timer? _poller;
  bool _alive = true;
  bool _fetching = false;

  Future<Map<String, String>> _authHeaders() async {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  int get _ticketId => int.tryParse('${widget.ticket['id']}') ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    _alive = false;
    _poller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _replyCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_alive) return;
    if (state == AppLifecycleState.resumed) {
      _loadTicket(silent: true);
    }
  }

  Future<void> _bootstrap() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token') ?? '';
    await _loadTicket();
    _startPollingIfNeeded();
  }

  bool _isClosed(Map<String, dynamic> t) {
    final st = (t['status'] ?? '').toString().toLowerCase().trim();
    return st == 'closed' || st == 'resolved';
  }

  bool _canSendMessage(Map<String, dynamic> t) => !_isClosed(t);

  List<Map<String, dynamic>> _messagesFromTicket(Map<String, dynamic> t) {
    final m = t['messages'];
    if (m is List) {
      return m.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  void _startPollingIfNeeded() {
    _poller?.cancel();

    final t = _ticket ?? widget.ticket;
    if (_ticketId <= 0) return;
    if (_isClosed(t)) return;

    _poller = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_alive || !mounted) return;
      _loadTicket(silent: true);
    });
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _loadTicket({bool silent = false}) async {
    if (_ticketId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ticket = widget.ticket;
      });
      return;
    }

    if (_fetching) return;
    _fetching = true;

    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await http.get(
        Uri.parse('$_BASE/tickets/$_ticketId'),
        headers: await _authHeaders(),
      );

      if (!_alive || !mounted) return;

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);

        Map<String, dynamic>? t;
        if (j is Map && j['data'] is Map) {
          t = (j['data'] as Map).cast<String, dynamic>();
        } else if (j is Map) {
          t = j.cast<String, dynamic>();
        }

        final next = t ?? widget.ticket;

        setState(() {
          _ticket = next;
          _loading = false;
        });

        if (_isClosed(next)) {
          _stopPolling();
        } else {
          _startPollingIfNeeded();
        }
      } else {
        setState(() {
          _ticket = _ticket ?? widget.ticket;
          _loading = false;
        });
      }
    } catch (_) {
      if (!_alive || !mounted) return;
      setState(() {
        _ticket = _ticket ?? widget.ticket;
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _replyCtl.text.trim();
    if (text.isEmpty) return;

    final t = _ticket ?? widget.ticket;

    if (!_canSendMessage(t)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ticket ya está cerrado.')),
      );
      return;
    }

    setState(() => _sending = true);

    final optimistic = {
      'id': -DateTime.now().millisecondsSinceEpoch,
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
      'sender': {'name': 'Tú'},
    };

    setState(() {
      final current = Map<String, dynamic>.from(_ticket ?? widget.ticket);
      final msgs = _messagesFromTicket(current);
      msgs.add(optimistic);
      current['messages'] = msgs;
      _ticket = current;
    });

    _replyCtl.clear();

    try {
      final res = await http.post(
        Uri.parse('$_BASE/tickets/$_ticketId/messages'),
        headers: await _authHeaders(),
        body: jsonEncode({'message': text}),
      );

      if (!_alive || !mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _loadTicket(silent: true);
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No tienes permiso para escribir en este ticket.')),
        );
        await _loadTicket(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al enviar: ${res.statusCode} ${res.body}')),
        );
        await _loadTicket(silent: true);
      }
    } catch (e) {
      if (!_alive || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al enviar: $e')),
      );
      await _loadTicket(silent: true);
    }

    if (!_alive || !mounted) return;
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket ?? widget.ticket;

    final id = t['id']?.toString() ?? '-';
    final subject = (t['subject'] ?? t['titulo'] ?? 'Sin asunto').toString();
    final status = (t['status'] ?? t['estado'] ?? 'abierto').toString();
    final created = (t['created_at'] ?? '').toString();

    final messages = _messagesFromTicket(t);
    final canSend = _canSendMessage(t);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #$id'),
        actions: [
          IconButton(
            onPressed: () => _loadTicket(silent: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Estado: $status'),
                          if (created.isNotEmpty) Text('Creado: $created'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text('Sin mensajes todavía.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final m = messages[i];
                            final body = (m['message'] ?? '').toString();

                            final sender = m['sender'];
                            String who = 'Usuario';
                            if (sender is Map) {
                              who = (sender['name'] ??
                                      sender['email'] ??
                                      'Usuario')
                                  .toString();
                            }

                            final when = (m['created_at'] ?? '').toString();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(who,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if (when.isNotEmpty)
                                      Text(
                                        when,
                                        style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(body),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _replyCtl,
                        enabled: canSend && !_sending,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: canSend
                              ? 'Escribe un mensaje…'
                              : 'Ticket cerrado',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (!canSend || _sending) ? null : _sendMessage,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label:
                              Text(_sending ? 'Enviando…' : 'Enviar mensaje'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
