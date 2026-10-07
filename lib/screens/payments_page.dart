import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_model.dart';
import '../services/payment_api.dart';

/// Payment history. Customers see what they paid; service providers see what they collected.
/// The role is read from the saved login, so the same screen serves both.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  bool _isProvider = false;
  String? _error;
  List<PaymentRecord> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final userId = prefs.getInt('userId');
      _isProvider = role == 'SERVICE_PROVIDER';

      final list = _isProvider
          ? await PaymentApi.providerPayments(userId ?? 0)
          : await PaymentApi.myPayments();

      if (!mounted) return;
      setState(() {
        _payments = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double get _totalPaid => _payments
      .where((p) => p.status == 'SUCCESS')
      .fold(0.0, (sum, p) => sum + p.amount);

  Color _statusColor(String s) {
    switch (s) {
      case 'SUCCESS':
        return const Color(0xFF059669);
      case 'FAILED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'SUCCESS':
        return 'Paid';
      case 'FAILED':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final mm = l.minute.toString().padLeft(2, '0');
    final ap = l.hour >= 12 ? 'PM' : 'AM';
    return '${l.day} ${m[l.month - 1]} ${l.year}, $h:$mm $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isProvider ? 'Payments Received' : 'My Payments'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0C1B2E),
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B7EFF), Color(0xFF1D4ED8)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isProvider ? 'Total collected' : 'Total paid',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('₹${_totalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_payments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text('No payments yet',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
            ..._payments.map(_tile),
          ],
        ),
      ),
    );
  }

  Widget _tile(PaymentRecord p) {
    final color = _statusColor(p.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(_formatDate(p.paidAt ?? p.createdAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (p.razorpayPaymentId != null)
                  Text('Ref: ${p.razorpayPaymentId}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${p.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(p.status),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
