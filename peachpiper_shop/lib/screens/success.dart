import 'package:flutter/material.dart';
import '../main.dart';
import 'track.dart';

class SuccessScreen extends StatelessWidget {
  final String number;
  const SuccessScreen(this.number, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.check_circle, color: Color(0xFF1F7A4D), size: 72),
            const SizedBox(height: 16),
            const Text('Thank you! Your order is placed', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Order number $number', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: wine, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('We will send updates on WhatsApp. You can track your order anytime from the app.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.4)),
            const SizedBox(height: 28),
            FilledButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackScreen(number: number))), child: const Text('Track order')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => goTab(context, 0), child: const Text('Continue shopping')),
          ]),
        ),
      ),
    );
  }
}
