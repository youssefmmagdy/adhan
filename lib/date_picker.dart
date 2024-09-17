import 'package:flutter/material.dart';
import "package:intl/intl.dart";

final formatter = DateFormat.yMd();

class DatePicker extends StatefulWidget {
  const DatePicker(
      {super.key,
      required this.setDate,
      required this.getLocation,
      required this.selectedDate});

  final void Function(DateTime) setDate;
  final void Function() getLocation;
  final DateTime selectedDate;

  @override
  State<DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<DatePicker> {
  Future<void> presentDatePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 1),
    );

    if (pickedDate != null && pickedDate != widget.selectedDate) {
      setState(() {
        widget.setDate(pickedDate);
        widget.getLocation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          formatter.format(widget.selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
        IconButton(
          onPressed: presentDatePicker,
          icon: const Icon(
            Icons.calendar_month,
            size: 30,
          ),
        ),
      ],
    );
  }
}
