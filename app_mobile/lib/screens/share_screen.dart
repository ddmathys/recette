import 'package:flutter/material.dart';

import '../models.dart';
import '../services/household_service.dart';
import '../theme.dart';

/// "Activer le partage" — rejoindre la bibliothèque d'un autre compte (ou
/// revenir à la sienne). Mirrors ShareSettings.tsx on the web.
class ShareScreen extends StatefulWidget {
  final String uid;
  final UserProfile profile;
  final Household? household;

  const ShareScreen({super.key, required this.uid, required this.profile, required this.household});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _household = HouseholdService();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _isOwnHousehold => widget.profile.householdId == widget.uid;

  Future<void> _join() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _household.joinHousehold(widget.uid, _emailCtrl.text.trim());
      _emailCtrl.clear();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _household.leaveHousehold(widget.uid, widget.profile.householdId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partage')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isOwnHousehold) ...[
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Tu vois '),
                  const TextSpan(text: 'ta propre bibliothèque', style: TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '.'),
                  if (widget.household != null && widget.household!.members.length > 1)
                    TextSpan(
                      text:
                          ' Elle est aussi partagée avec ${widget.household!.members.length - 1} autre compte${widget.household!.members.length - 1 > 1 ? 's' : ''}.',
                    ),
                ])),
                const SizedBox(height: 20),
                const Text('REJOINDRE LA BIBLIOTHÈQUE DE QUELQU\'UN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: .4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(hintText: 'e-mail de la personne'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _busy ? null : _join,
                      child: const Text('Rejoindre'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu verras et pourras modifier ses recettes (et elle les tiennes), avec une pastille qui indique qui a créé quoi.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ] else ...[
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Tu vois la bibliothèque de '),
                  TextSpan(text: widget.household?.ownerEmail ?? '…', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '.'),
                ])),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy ? null : _leave,
                  child: const Text('Revenir à ma bibliothèque'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
