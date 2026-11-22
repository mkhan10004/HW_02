import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.board,
    required this.rulesChecks,
    required this.emulator,
  });

  final AuthService auth;
  final BoardService board;
  final bool rulesChecks, emulator;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: auth.changes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Could not check your sign-in state. Relaunch the app.',
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user == null) {
        return AuthScreen(
          auth: auth,
          board: board,
          rulesChecks: rulesChecks,
          emulator: emulator,
        );
      }
      return ProfileGate(
        key: ValueKey(user.uid),
        uid: user.uid,
        auth: auth,
        board: board,
        rulesChecks: rulesChecks,
        emulator: emulator,
      );
    },
  );
}

class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.emulator = false,
  });
  final String title;
  final List<Widget> children;
  final bool emulator;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(emulator ? 'Vault · Local emulator' : 'Message Board Vault'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 22),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.board,
    required this.rulesChecks,
    required this.emulator,
  });
  final AuthService auth;
  final BoardService board;
  final bool rulesChecks, emulator;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (_register) {
        await widget.auth.register(email, _password.text);
      } else {
        await widget.auth.signIn(email, _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: _register ? 'Create your account' : 'Sign in',
    emulator: widget.emulator,
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password.';
                }
                if (_register && value.length < 6) {
                  return 'Use at least 6 characters.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorText(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Please wait…'
                    : _register
                    ? 'Register'
                    : 'Sign in',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _register = !_register;
                      _error = null;
                      _form.currentState?.reset();
                    }),
              child: Text(_register ? 'Back to sign in' : 'Create an account'),
            ),
          ],
        ),
      ),
      if (widget.rulesChecks)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => showRuleResult(
                  context,
                  'Signed-out board read',
                  widget.board.checkSignedOutRead,
                ),
          child: const Text('Test signed-out board read'),
        ),
    ],
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.uid,
    required this.auth,
    required this.board,
    required this.rulesChecks,
    required this.emulator,
  });
  final String uid;
  final AuthService auth;
  final BoardService board;
  final bool rulesChecks, emulator;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<Profile?> _profile = widget.board.loadProfile(widget.uid);
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.board.saveProfile(
        Profile(widget.uid, _first.text.trim(), _last.text.trim()),
      );
      if (mounted) {
        setState(() => _profile = widget.board.loadProfile(widget.uid));
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Widget _nameField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !_busy,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'Enter your ${label.toLowerCase()}.'
            : null,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<Profile?>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = snapshot.data;
      if (profile != null) {
        return BoardScreen(
          profile: profile,
          auth: widget.auth,
          board: widget.board,
          rulesChecks: widget.rulesChecks,
          emulator: widget.emulator,
        );
      }
      return FormPage(
        title: 'Finish registration',
        emulator: widget.emulator,
        children: [
          if (snapshot.hasError) ...[
            ErrorText(friendlyError(snapshot.error!)),
            FilledButton(
              onPressed: () => setState(() {
                _error = null;
                _profile = widget.board.loadProfile(widget.uid);
              }),
              child: const Text('Retry profile lookup'),
            ),
          ] else
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _nameField(_first, 'First name'),
                  const SizedBox(height: 8),
                  _nameField(_last, 'Last name'),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save profile'),
                  ),
                ],
              ),
            ),
          if (_error != null) ErrorText(_error!),
          TextButton(
            onPressed: _busy ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      );
    },
  );
}

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.profile,
    required this.auth,
    required this.board,
    required this.rulesChecks,
    required this.emulator,
  });
  final Profile profile;
  final AuthService auth;
  final BoardService board;
  final bool rulesChecks, emulator;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _draft = TextEditingController();
  late Stream<BoardData> _stream = widget.board.watchBoard();
  String? _operationId;
  String? _operationText;
  String? _error;
  bool _busy = false;
  bool _signingOut = false;

  Future<void> _post() async {
    if (_busy || _signingOut) return;
    final text = _draft.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a message before posting.');
      return;
    }
    if (_operationId == null || _operationText != text) {
      _operationId = widget.board.newPostId();
      _operationText = text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.board.create(_operationId!, widget.profile, text);
      if (!mounted) return;
      _draft.clear();
      _operationId = null;
      _operationText = null;
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _messageAction(Message message, String action) {
    if (action == 'edit' || action == 'delete') {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MessageDialog(
          board: widget.board,
          message: message,
          delete: action == 'delete',
        ),
      );
      return;
    }
    final deleting = action == 'probe-delete';
    showRuleResult(
      context,
      deleting ? 'Cross-user delete' : 'Cross-user update',
      () => widget.board.checkOwnership(message, delete: deleting),
    );
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.emulator ? 'Board · Local emulator' : 'Message Board'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: _busy || _signingOut ? null : _signOut,
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Signed in as ${widget.profile.name}'),
                ),
              ),
              if (widget.rulesChecks)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Rules checks enabled. Use disposable test posts for cross-user checks.',
                  ),
                ),
              Expanded(
                child: StreamBuilder<BoardData>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ErrorText(friendlyError(snapshot.error!)),
                            TextButton(
                              onPressed: () => setState(
                                () => _stream = widget.board.watchBoard(),
                              ),
                              child: const Text('Reconnect'),
                            ),
                          ],
                        ),
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        if (data.fromCache)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Showing cached messages.'),
                          ),
                        Expanded(
                          child: data.messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet. Post the first one.',
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  itemCount: data.messages.length,
                                  itemBuilder: (context, index) =>
                                      _messageCard(data.messages[index]),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ErrorText(_error!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _draft,
                        enabled: !_busy && !_signingOut,
                        decoration: const InputDecoration(labelText: 'Message'),
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy || _signingOut ? null : _post,
                      child: Text(_busy ? 'Posting…' : 'Post'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _messageCard(Message message) {
    final own = message.authorUid == widget.profile.uid;
    final date = message.createdAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final detail = [
      if (date != null)
        '${localizations.formatShortDate(date)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
      if (message.edited) 'Edited',
      if (message.pending) 'Waiting to sync',
    ].join(' · ');
    return Card(
      key: ValueKey(message.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.authorName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (own || widget.rulesChecks)
                  PopupMenuButton<String>(
                    enabled: !_signingOut,
                    tooltip: 'Message actions',
                    onSelected: (action) => _messageAction(message, action),
                    itemBuilder: (context) => own
                        ? const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ]
                        : const [
                            PopupMenuItem(
                              value: 'probe-update',
                              child: Text('Test cross-user update'),
                            ),
                            PopupMenuItem(
                              value: 'probe-delete',
                              child: Text('Test cross-user delete'),
                            ),
                          ],
                  ),
              ],
            ),
            Text(message.text),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class MessageDialog extends StatefulWidget {
  const MessageDialog({
    super.key,
    required this.board,
    required this.message,
    required this.delete,
  });
  final BoardService board;
  final Message message;
  final bool delete;

  @override
  State<MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<MessageDialog> {
  late final _controller = TextEditingController(text: widget.message.text);
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    final text = _controller.text.trim();
    if (!widget.delete && text.isEmpty) {
      setState(() => _error = 'Enter a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.delete) {
        await widget.board.delete(widget.message.id);
      } else {
        await widget.board.update(widget.message.id, text);
      }
      if (mounted) {
        setState(() => _busy = false);
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.delete ? 'Delete this message?' : 'Edit message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.delete)
            Text(widget.message.text)
          else
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          if (_busy) const Text('Waiting for Firestore to confirm…'),
          if (_error != null) ErrorText(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.delete ? 'Delete' : 'Save'),
        ),
      ],
    ),
  );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

Future<void> showRuleResult(
  BuildContext context,
  String title,
  Future<void> Function() check,
) {
  final outcome = _ruleOutcome(check);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: FutureBuilder<String>(
        future: outcome,
        builder: (context, snapshot) =>
            Text(snapshot.data ?? 'Waiting for Firestore…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<String> _ruleOutcome(Future<void> Function() check) async {
  try {
    await check();
    return 'FAIL · Firestore allowed the request.';
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied') {
      return 'PASS · Firestore returned permission-denied.';
    }
    return 'INCONCLUSIVE · Firestore returned ${error.code}.';
  } catch (error) {
    return 'INCONCLUSIVE · ${friendlyError(error)}';
  }
}
