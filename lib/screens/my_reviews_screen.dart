import 'package:flutter/material.dart';

import '../services/local_reviews_service.dart';
import 'place_details_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _service = LocalReviewsService();
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final reviews = await _service.getReviews();
    if (mounted) setState(() => _reviews = reviews);
  }

  Future<void> _open(Map<String, dynamic> review) async {
    final place = review['place'];
    if (place is! Map) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaceDetailsScreen(place: Map<String, dynamic>.from(place)),
    ));
    await _refresh();
  }

  Future<void> _delete(String id) async {
    await _service.delete(id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('As tuas avaliações')),
      body: _reviews.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Ainda não escreveste avaliações. Abre um lugar e toca em “Avaliar este lugar”.',
                  textAlign: TextAlign.center),
            ))
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _reviews.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final place = review['place'];
                final name = place is Map ? (place['name'] ?? 'Lugar').toString() : 'Lugar';
                return ListTile(
                  onTap: () => _open(review),
                  title: Text(name),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('★ ${review['rating']}/5', style: const TextStyle(
                        color: Color(0xFFE2A827), fontWeight: FontWeight.w700)),
                    Text((review['comment'] ?? '').toString(), maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ]),
                  trailing: IconButton(
                    tooltip: 'Apagar avaliação', icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete((review['placeId'] ?? '').toString()),
                  ),
                );
              },
            ),
    );
  }
}
