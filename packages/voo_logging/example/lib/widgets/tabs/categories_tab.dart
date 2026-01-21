import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import '../components/section_title.dart';
import '../components/category_button.dart';
import '../components/code_example.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Log by Category'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CategoryButton(
                label: 'Auth',
                icon: Icons.lock,
                color: Colors.purple,
                onPressed: () {
                  VooLogger.info(
                    'User logged in',
                    category: 'Auth',
                    tag: 'login',
                    metadata: {'method': 'email'},
                  );
                },
              ),
              CategoryButton(
                label: 'Network',
                icon: Icons.cloud,
                color: Colors.blue,
                onPressed: () {
                  VooLogger.info(
                    'API request completed',
                    category: 'Network',
                    tag: 'api',
                    metadata: {'endpoint': '/users'},
                  );
                },
              ),
              CategoryButton(
                label: 'Analytics',
                icon: Icons.analytics,
                color: Colors.green,
                onPressed: () {
                  VooLogger.info(
                    'Event tracked',
                    category: 'Analytics',
                    tag: 'event',
                    metadata: {'name': 'page_view'},
                  );
                },
              ),
              CategoryButton(
                label: 'Payment',
                icon: Icons.payment,
                color: Colors.orange,
                onPressed: () {
                  VooLogger.info(
                    'Payment processed',
                    category: 'Payment',
                    tag: 'transaction',
                    metadata: {'amount': 99.99},
                  );
                },
              ),
              CategoryButton(
                label: 'System',
                icon: Icons.settings,
                color: Colors.grey,
                onPressed: () {
                  VooLogger.debug('System check', category: 'System', tag: 'health');
                },
              ),
              CategoryButton(
                label: 'Error',
                icon: Icons.error,
                color: Colors.red,
                onPressed: () {
                  VooLogger.error(
                    'Operation failed',
                    category: 'Error',
                    tag: 'failure',
                    error: Exception('Database error'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CodeExample(
            title: 'Structured Logging',
            code: '''VooLogger.info(
  'User completed purchase',
  category: 'Payment',
  tag: 'checkout_complete',
  metadata: {
    'orderId': 'ORD-123',
    'amount': 99.99,
    'currency': 'USD',
    'items': 3,
  },
);''',
          ),
        ],
      ),
    );
  }
}
