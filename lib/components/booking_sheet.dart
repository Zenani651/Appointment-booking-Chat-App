import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/services/profile/business_profile_service.dart';
import 'package:chat_app/services/slots/slot_service.dart';
import 'package:chat_app/utils/business_hours.dart';
import 'package:chat_app/utils/slots.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingDraft {
  final String service;
  final DateTime dateTime;
  final String note;

  const BookingDraft({
    required this.service,
    required this.dateTime,
    required this.note,
  });
}

/// Shows the "Request an appointment" form with the business's free slots.
/// Returns null if dismissed.
Future<BookingDraft?> showBookingSheet(
  BuildContext context, {
  required String businessID,
}) {
  return showModalBottomSheet<BookingDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BookingSheet(businessID: businessID),
  );
}

class _BookingSheet extends StatefulWidget {
  final String businessID;
  const _BookingSheet({required this.businessID});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _formKey = GlobalKey<FormState>();
  final _serviceController = TextEditingController();
  final _noteController = TextEditingController();

  late final Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  late DateTime _day;
  late Stream<Set<String>> _bookedStream;
  DateTime? _selected;
  String? _slotError;

  @override
  void initState() {
    super.initState();
    _profileFuture = BusinessProfileService().getProfile(widget.businessID);
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _bookedStream = SlotService().bookedSlotIds(widget.businessID, _day);
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _pickDay(DateTime day) {
    setState(() {
      _day = day;
      _selected = null;
      _slotError = null;
      _bookedStream = SlotService().bookedSlotIds(widget.businessID, day);
    });
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    if (_selected == null) {
      setState(() => _slotError = 'Choose a time slot');
      return;
    }
    if (!formValid) return;

    Navigator.pop(
      context,
      BookingDraft(
        service: _serviceController.text.trim(),
        dateTime: _selected!,
        note: _noteController.text.trim(),
      ),
    );
  }

  String _dayChipLabel(DateTime d, int index) {
    if (index == 0) return 'Today';
    return '${_weekdays[d.weekday - 1]} ${d.day}';
  }

  Widget _buildDayPicker() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final d = start.add(Duration(days: index));
          return ChoiceChip(
            label: Text(_dayChipLabel(d, index)),
            selected: d == _day,
            onSelected: (_) => _pickDay(d),
          );
        },
      ),
    );
  }

  Widget _buildSlots(TimeOfDay opens, TimeOfDay closes, int minutes) {
    return StreamBuilder<Set<String>>(
      stream: _bookedStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25),
            child: Text('Could not load available times.'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final booked = snapshot.data!;
        final now = DateTime.now();
        final slots =
            generateSlots(
              _day,
              opens,
              closes,
              minutes,
            ).where((s) => s.isAfter(now)).toList();
        final anyFree = slots.any((s) => !booked.contains(slotId(s)));

        if (slots.isEmpty || !anyFree) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 8),
            child: Text('No free slots on this day. Try another day.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                slots.map((slot) {
                  final taken = booked.contains(slotId(slot));
                  final label = formatHm(TimeOfDay.fromDateTime(slot));
                  return ChoiceChip(
                    label: Text(label),
                    selected: _selected == slot,
                    onSelected:
                        taken
                            ? null
                            : (_) => setState(() {
                              _selected = slot;
                              _slotError = null;
                            }),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data?.data();
            final opens = parseHm(data?['opensAt']?.toString());
            final closes = parseHm(data?['closesAt']?.toString());
            final minutes = (data?['slotMinutes'] as num?)?.toInt() ?? 60;

            if (opens == null || closes == null) {
              return const Padding(
                padding: EdgeInsets.all(25),
                child: Text(
                  "This business hasn't published its opening times yet, so "
                  'there are no slots to book. Send them a message to arrange '
                  'a time.',
                ),
              );
            }

            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(25, 20, 25, 12),
                      child: Text(
                        'Request an appointment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    MyTextfields(
                      hintText: 'Service (e.g. Haircut)',
                      obscureText: false,
                      controller: _serviceController,
                      maxLength: 60,
                      validator:
                          (value) =>
                              (value ?? '').trim().isEmpty
                                  ? 'Please enter a service'
                                  : null,
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(25, 0, 25, 8),
                      child: Text(
                        'Pick a day',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _buildDayPicker(),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 8),
                      child: Text(
                        'Available times ($minutes min)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _buildSlots(opens, closes, minutes),
                    if (_slotError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(25, 6, 25, 0),
                        child: Text(
                          _slotError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    MyTextfields(
                      hintText: 'Note (optional)',
                      obscureText: false,
                      controller: _noteController,
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 16),
                    MyButton(text: 'Send request', onTap: _submit),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
