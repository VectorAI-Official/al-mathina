import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/voice_search_dialog.dart';
import 'return_search_results_screen.dart';

/// Entry point for the "Return Item" flow.
///
/// Visual clone of the home search bar row (rounded search field + mic
/// icon opening `VoiceSearchDialog`).
class ReturnItemSearchScreen extends StatefulWidget {
  const ReturnItemSearchScreen({super.key});

  @override
  State<ReturnItemSearchScreen> createState() => _ReturnItemSearchScreenState();
}

class _ReturnItemSearchScreenState extends State<ReturnItemSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnSearchResultsScreen(query: query.trim()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFFFC),
      appBar: AppBar(
        title: Text(
          provider.text('return_item'),
          style: const TextStyle(color: kPrimaryColor),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFCFFFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Color(0xFF868889), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: provider.text('search'),
                    hintStyle: const TextStyle(
                      color: Color(0xFF868889),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: _onSearch,
                ),
              ),
              // Voice Search Button
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Color(0xFF66BB6A),
                    size: 20,
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => VoiceSearchDialog(
                      currentLanguage: provider.currentLanguage,
                      onSearchQuery: (query) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _searchController.text = query;
                          _onSearch(query);
                        });
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
