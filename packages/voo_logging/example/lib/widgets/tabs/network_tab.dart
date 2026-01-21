import 'package:flutter/material.dart';
import '../components/section_title.dart';
import '../components/code_example.dart';

class NetworkTab extends StatelessWidget {
  final void Function(String url, {bool isPost}) onMakeRequest;

  const NetworkTab({
    super.key,
    required this.onMakeRequest,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Network Logging with Dio'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => onMakeRequest('https://jsonplaceholder.typicode.com/posts/1'),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('GET Request'),
              ),
              FilledButton.icon(
                onPressed: () => onMakeRequest(
                  'https://jsonplaceholder.typicode.com/posts',
                  isPost: true,
                ),
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('POST Request'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onMakeRequest('https://httpstat.us/404'),
                icon: const Icon(Icons.error_outline, size: 18),
                label: const Text('404 Error'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onMakeRequest('https://httpstat.us/500'),
                icon: const Icon(Icons.dangerous, size: 18),
                label: const Text('500 Error'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CodeExample(
            title: 'Dio Integration',
            code: '''final dio = Dio();
final interceptor = VooDioInterceptor();

dio.interceptors.add(InterceptorsWrapper(
  onRequest: interceptor.onRequest,
  onResponse: interceptor.onResponse,
  onError: interceptor.onError,
));

// All requests are now logged automatically!
await dio.get('https://api.example.com/data');''',
          ),
        ],
      ),
    );
  }
}
