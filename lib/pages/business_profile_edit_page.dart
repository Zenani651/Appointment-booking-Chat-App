import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/services/profile/business_profile_service.dart';
import 'package:chat_app/utils/business_hours.dart';
import 'package:chat_app/utils/validators.dart';
import 'package:flutter/material.dart';

class BusinessProfileEditPage extends StatefulWidget {
  const BusinessProfileEditPage({super.key});

  @override
  State<BusinessProfileEditPage> createState() =>
      _BusinessProfileEditPageState();
}

class _BusinessProfileEditPageState extends State<BusinessProfileEditPage> {
  static const _slotOptions = [15, 30, 45, 60, 90, 120];

  final _formKey = GlobalKey<FormState>();
  final _service = BusinessProfileService();

  final _announcement = TextEditingController();
  final _description = TextEditingController();
  final _hours = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  TimeOfDay? _opensAt;
  TimeOfDay? _closesAt;
  int _slotMinutes = 60;
  String? _timeError;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _announcement.dispose();
    _description.dispose();
    _hours.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = AuthService().getCurrentUser()?.uid;
      if (uid != null) {
        final snap = await _service.getProfile(uid);
        final data = snap.data();
        if (data != null) {
          _announcement.text = (data['announcement'] ?? '').toString();
          _description.text = (data['description'] ?? '').toString();
          _hours.text = (data['hours'] ?? '').toString();
          _phone.text = (data['phone'] ?? '').toString();
          _address.text = (data['address'] ?? '').toString();
          _opensAt = parseHm(data['opensAt']?.toString());
          _closesAt = parseHm(data['closesAt']?.toString());
          final saved = (data['slotMinutes'] as num?)?.toInt();
          if (saved != null && _slotOptions.contains(saved)) {
            _slotMinutes = saved;
          }
        }
      }
    } catch (_) {
      // Start with an empty form if loading fails.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickTime({required bool opening}) async {
    final initial =
        (opening ? _opensAt : _closesAt) ??
        TimeOfDay(hour: opening ? 8 : 17, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (opening) {
        _opensAt = picked;
      } else {
        _closesAt = picked;
      }
      _timeError = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Both times, or neither.
    if ((_opensAt == null) != (_closesAt == null)) {
      setState(() => _timeError = 'Set both opening and closing time.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.saveMyProfile(
        description: _description.text,
        hours: _hours.text,
        phone: _phone.text,
        address: _address.text,
        announcement: _announcement.text,
        opensAt: _opensAt == null ? '' : formatHm(_opensAt!),
        closesAt: _closesAt == null ? '' : formatHm(_closesAt!),
        slotMinutes: _slotMinutes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Business profile saved')));
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Save business profile failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your profile.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay? value,
    required bool opening,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _pickTime(opening: opening),
        icon: const Icon(Icons.schedule, size: 18),
        label: Text(value == null ? label : '$label ${formatHm(value)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Business profile'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(25, 8, 25, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Announcement (shown at the top of your profile)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      MyTextfields(
                        hintText: 'e.g. Closed Friday for the public holiday',
                        obscureText: false,
                        controller: _announcement,
                        maxLines: 2,
                        maxLength: 200,
                      ),
                      const SizedBox(height: 14),
                      MyTextfields(
                        hintText: 'About your business',
                        obscureText: false,
                        controller: _description,
                        maxLines: 3,
                        maxLength: 300,
                      ),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(25, 0, 25, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Opening and closing time (used for booking slots)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Row(
                          children: [
                            _timeButton(
                              label: 'Opens',
                              value: _opensAt,
                              opening: true,
                            ),
                            const SizedBox(width: 12),
                            _timeButton(
                              label: 'Closes',
                              value: _closesAt,
                              opening: false,
                            ),
                          ],
                        ),
                      ),
                      if (_timeError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 6, 25, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _timeError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      if (_opensAt != null || _closesAt != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: TextButton(
                              onPressed:
                                  () => setState(() {
                                    _opensAt = null;
                                    _closesAt = null;
                                    _timeError = null;
                                  }),
                              child: const Text('Clear times'),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(25, 4, 25, 0),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Appointment length')),
                            DropdownButton<int>(
                              value: _slotMinutes,
                              items:
                                  _slotOptions
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text('$m min'),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _slotMinutes = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      MyTextfields(
                        hintText:
                            'Hours details (e.g. Mon-Fri, Sat until 14:00)',
                        obscureText: false,
                        controller: _hours,
                        maxLength: 200,
                      ),
                      const SizedBox(height: 14),
                      MyTextfields(
                        hintText: 'Phone number',
                        obscureText: false,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                        maxLength: 20,
                      ),
                      const SizedBox(height: 14),
                      MyTextfields(
                        hintText: 'Address',
                        obscureText: false,
                        controller: _address,
                        maxLines: 2,
                        maxLength: 150,
                      ),
                      const SizedBox(height: 20),
                      MyButton(
                        text: 'Save',
                        onTap: _save,
                        isLoading: _isSaving,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }
}
