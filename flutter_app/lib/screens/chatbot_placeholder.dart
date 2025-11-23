// lib/screens/chatbot_placeholder.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatbotPlaceholder extends StatefulWidget {
  const ChatbotPlaceholder({Key? key}) : super(key: key);

  @override
  State<ChatbotPlaceholder> createState() => _ChatbotPlaceholderState();
}

class _ChatbotPlaceholderState extends State<ChatbotPlaceholder> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // {"from":"user"/"bot","msg":String, "typing":bool?}
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  // Simple patterns
  final RegExp _complaintIdPattern = RegExp(r'\bRWC[A-Z]{3}\d{5}\b', caseSensitive: false);
  String? _awaitingFeedbackFor;

  @override
  void initState() {
    super.initState();
  }

  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showRealtimeUpdates() async {
    // Fetch counts for current user (fallback to local storage)
    int total = 0;
    int open = 0;
    int inProgress = 0;
    int resolved = 0;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final q = await FirebaseFirestore.instance
            .collection('complaints')
            .where('userEmail', isEqualTo: user.email)
            .get();
        total = q.docs.length;
        for (final d in q.docs) {
          final s = (d.data()['status'] ?? 'open').toString();
          if (s == 'open') open++;
          else if (s == 'in-progress' || s == 'in_progress') inProgress++;
          else if (s == 'resolved') resolved++;
        }
      } catch (e) {
        debugPrint('RealtimeCounts firestore failed: $e');
      }
    }

    // fallback / merge with local stored complaints
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      if (user == null) total = list.length;
      for (final item in list) {
        try {
          final m = json.decode(item) as Map<String, dynamic>;
          final s = (m['status'] ?? 'open').toString();
          if (s == 'open') open++;
          else if (s == 'in-progress' || s == 'in_progress') inProgress++;
          else if (s == 'resolved') resolved++;
        } catch (_) {}
      }
    } catch (_) {}

    // Show nicely formatted dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Real-time complaint summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total filed: $total'),
            const SizedBox(height: 6),
            Text('Open: $open', style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 4),
            Text('In-progress: $inProgress', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 4),
            Text('Resolved: $resolved', style: const TextStyle(color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _startKnowledgeBase() async {
    // Invite user to ask KB questions about railway complaints
    _replaceBotMessageWith(
        "Knowledge Base: Ask any question about railway complaints — what to include, how it's processed, or examples. I'll answer your questions.");
    // clear the input so the user can type their question
    _msgCtrl.text = '';
  }

  Future<void> _verifyComplaintDialog() async {
    final idCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify my complaint'),
        content: TextField(
          controller: idCtrl,
          decoration: const InputDecoration(hintText: 'Enter Complaint ID (e.g. RWCOVR00001)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
    if (res == true) {
      final id = idCtrl.text.trim();
      if (id.isEmpty) return;
      _addUserMessage('Check $id');
      _addBotTyping();
      await _presentComplaintWithFeedback(id);
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({"from": "user", "msg": text});
    });
    _scrollToEnd();
  }

  void _addBotTyping() {
    setState(() {
      _messages.add({"from": "bot", "msg": "typing...", "typing": true});
    });
    _scrollToEnd();
  }

  void _replaceBotMessageWith(String reply) {
    setState(() {
      // remove last bot typing message if exists
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i]["from"] == "bot" && (_messages[i]["typing"] ?? false) == true) {
          _messages[i] = {"from": "bot", "msg": reply};
          return;
        }
      }
      // otherwise just add
      _messages.add({"from": "bot", "msg": reply});
    });
    _scrollToEnd();
  }

  void _addBotImage(String data) {
    setState(() {
      _messages.add({"from": "bot", "msg": data, "type": "image"});
    });
    _scrollToEnd();
  }

  void _scrollToEnd([int ms = 300]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: ms),
            curve: Curves.easeOut,
          );
        }
      } catch (_) {}
    });
  }

  Widget _formatMessageText(String text, bool isUser) {
    // Parse **bold** markers and build TextSpans
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    final spans = <TextSpan>[];
    int current = 0;
    for (final m in boldPattern.allMatches(text)) {
      if (m.start > current) {
        spans.add(TextSpan(
            text: text.substring(current, m.start),
            style: TextStyle(color: isUser ? Colors.white : Colors.black87)));
      }
      final boldText = m.group(1) ?? '';
      spans.add(TextSpan(
          text: boldText,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          )));
      current = m.end;
    }
    if (current < text.length) {
      spans.add(TextSpan(
          text: text.substring(current),
          style: TextStyle(color: isUser ? Colors.white : Colors.black87)));
    }

    return RichText(
      text: TextSpan(children: spans, style: TextStyle(fontSize: 15)),
    );
  }

  Widget _buildImageMessage(String data) {
    // data may be a data URI, an http(s) url, or a raw base64 string
    Widget img;
    try {
      if (data.startsWith('data:image')) {
        final comma = data.indexOf(',');
        final b64 = comma >= 0 ? data.substring(comma + 1) : data;
        final bytes = base64.decode(b64);
        img = Image.memory(bytes, width: 260, fit: BoxFit.contain);
      } else if (data.startsWith('http://') || data.startsWith('https://')) {
        img = Image.network(data, width: 260, fit: BoxFit.contain);
      } else {
        // assume raw base64
        final bytes = base64.decode(data);
        img = Image.memory(bytes, width: 260, fit: BoxFit.contain);
      }
    } catch (e) {
      img = const Text('Unable to display image');
    }

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: img),
    );
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // If awaiting simple yes/no feedback for a complaint, handle it here
    if (_awaitingFeedbackFor != null) {
      final low = text.toLowerCase();
      if (low == 'yes' || low == 'y' || low.contains('yes')) {
        _addUserMessage(text);
        _msgCtrl.clear();
        _handleFeedbackResponse(true, _awaitingFeedbackFor!);
        return;
      }
      if (low == 'no' || low == 'n' || low.contains('no') || low.contains('disagree')) {
        _addUserMessage(text);
        _msgCtrl.clear();
        _handleFeedbackResponse(false, _awaitingFeedbackFor!);
        return;
      }
      // otherwise continue as normal (user typed other question)
    }

    _addUserMessage(text);
    _msgCtrl.clear();

    _sending = true;
    _addBotTyping();

    try {
      // Check for complaint ID first
      final idMatch = _complaintIdPattern.firstMatch(text);
      if (idMatch != null) {
        final matched = idMatch.group(0)!;
        await _presentComplaintWithFeedback(matched);
        return;
      }

      // simple rule-based bot
      final low = text.toLowerCase();
      if (low.contains('hello') || low.contains('hi') || low.contains('hey')) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("Hello! 👋 How can I assist you today? You can ask about complaint status by sending your Complaint ID (e.g. RWCTEC00001) or ask how to file a complaint.");
        return;
      }

      if (low.contains('how') && (low.contains('file') || low.contains('submit') || low.contains('complaint'))) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("To file a complaint: Open 'Register Complaint', fill the required fields, then click 'Classify' to determine the relevant category/staff department. Finally, submit to save and track your complaint.");
        return;
      }

      if (low.contains('status') && low.contains('complaint')) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("Please provide your Complaint ID (it starts with `RWC`). I'll fetch the latest status for you.");
        return;
      }

      if (low.contains('thanks') || low.contains('thank you')) {
        await Future.delayed(const Duration(milliseconds: 400));
        _replaceBotMessageWith("You're welcome! If you need anything else, ask away 🙂");
        return;
      }

      // fallback helpful response: try to detect any complaint id inside text (looser)
      final looseId = _findLooseComplaintId(text);
      if (looseId != null) {
        await _presentComplaintWithFeedback(looseId);
        return;
      }

      // Default fallback
      await Future.delayed(const Duration(milliseconds: 600));
      _replaceBotMessageWith(
          "I didn't fully understand. Try sending a Complaint ID (like `RWCTEC00001`) to check status, or ask 'How to file a complaint'.");
    } finally {
      _sending = false;
    }
  }

  String? _findLooseComplaintId(String text) {
    // attempt to find things like RWC + letters + digits without strict length
    final r = RegExp(r'\bRWC[A-Z]{2,4}\d{3,6}\b', caseSensitive: false);
    final m = r.firstMatch(text);
    return m?.group(0);
  }

  Future<String> _handleComplaintQuery(String id, {String? displayId}) async {
    // Try Firestore first (best-effort). If error or not found -> fallback to SharedPreferences
    try {
      final doc = await FirebaseFirestore.instance.collection('complaints').doc(id).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        // Normalize createdAt
        String createdAtStr = '';
        final ca = data['createdAt'];
        if (ca is Timestamp) {
          createdAtStr = ca.toDate().toLocal().toString();
        } else if (ca is String) {
          createdAtStr = DateTime.tryParse(ca)?.toLocal().toString() ?? ca.toString();
        } else if (ca is DateTime) {
          createdAtStr = ca.toLocal().toString();
        }

        final status = (data['status'] ?? 'open').toString();
        final desc = (data['description'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        final responder = (data['lastUpdatedBy'] ?? data['userEmail'] ?? '').toString();
        final maskedResponder = _maskEmail(responder);
        final display = displayId ?? id;

        return "Complaint **${display}**\n• Status: **$status**\n• Department: $category\n• Submitted: ${createdAtStr.isNotEmpty ? createdAtStr.split('.').first : 'Unknown'}\n• Summary: ${_short(desc)}\n• Updated by: ${maskedResponder.isNotEmpty ? maskedResponder : 'N/A'}";
      }
    } catch (e) {
      debugPrint('Firestore complaint lookup failed: $e');
      // continue to fallback
    }

    // Fallback to SharedPreferences local lookup
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (final item in list) {
        try {
          final m = json.decode(item) as Map<String, dynamic>;
          final existingId = (m['id'] ?? m['docId'] ?? '').toString().toUpperCase();
          if (existingId == id.toUpperCase()) {
            final status = (m['status'] ?? 'open').toString();
            final desc = (m['description'] ?? '').toString();
            final category = (m['category'] ?? '').toString();
            final createdAtRaw = m['createdAt'];
            final createdAt = createdAtRaw != null ? createdAtRaw.toString() : 'Unknown';
            final display = displayId ?? id;
            return "Complaint **${display}** (local)\n• Status: **$status**\n• Department: $category\n• Submitted: ${createdAt.split('.').first}\n• Summary: ${_short(desc)}\n\nThis record is stored locally on your device. It will sync to cloud when online.";
          }
        } catch (_) {
          // ignore malformed item
        }
      }
    } catch (e) {
      debugPrint('Local complaint lookup failed: $e');
    }

    final display = displayId ?? id;
    return "I couldn't find a complaint with ID ${display}. Please check the ID and try again. If you just filed it, make sure the app finished saving (you can check 'Track Complaint').";
  }

  Future<void> _presentComplaintWithFeedback(String displayId) async {
    final lookupId = displayId.toUpperCase();
    final reply = await _handleComplaintQuery(lookupId, displayId: displayId);
    // show the complaint reply first
    await Future.delayed(const Duration(milliseconds: 300));
    _replaceBotMessageWith(reply);
    // then ask for feedback
    await Future.delayed(const Duration(milliseconds: 300));
    _replaceBotMessageWith("Is this helpful? Reply 'yes' or 'no'.");
    _awaitingFeedbackFor = displayId;
  }

  Future<void> _handleFeedbackResponse(bool helpful, String id) async {
    _addBotTyping();
    await Future.delayed(const Duration(milliseconds: 500));
    if (helpful) {
      _replaceBotMessageWith('Thank you — what else do you want to know?');
      _awaitingFeedbackFor = null;
      return;
    }

    // Not helpful: provide description and image info where available
    final lookupId = id.toUpperCase();
    final details = await _getComplaintDetails(lookupId);
    final desc = details['description'] as String? ?? '(no description)';
    final photos = details['photos'] as List<String>? ?? [];
    // present header text
    final header = "Here are the details for **$id**:\n• Description: ${_short(desc)}\n";
    _replaceBotMessageWith(header);

    if (photos.isNotEmpty) {
      // Only show the first image inline as requested
      final first = photos.first;
      _addBotImage(first);
      // Suggest an optional follow-up
      _replaceBotMessageWith("If you want an image summary, reply 'describe image'.");
    } else {
      _replaceBotMessageWith("• No images attached for this complaint.\n\nIf you expected an image, please check the Register Complaint view where photos are stored.");
    }
    _awaitingFeedbackFor = null;
  }

  Future<Map<String, Object?>> _getComplaintDetails(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('complaints').doc(id).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        final desc = (data['description'] ?? '').toString();
        // try common photo fields
        List<String> photos = [];
        if (data['referencePhotos'] is List) {
          photos = List.from(data['referencePhotos']).map((e) => e.toString()).toList();
        } else if (data['photoBase64'] != null) {
          photos = [data['photoBase64'].toString()];
        }

        // If no photos on the document, try subcollection 'images' and related collections
        if (photos.isEmpty) {
          try {
            final imgs = await FirebaseFirestore.instance.collection('complaints').doc(id).collection('images').limit(10).get();
            for (final d in imgs.docs) {
              final m = d.data();
              photos.addAll(_extractImageStringsFromMap(m));
            }
          } catch (e) {
            debugPrint('No images subcollection or failed: $e');
          }

          // search a set of likely collections for attached images referencing this complaint id
          final likely = ['complaint_images', 'attachments', 'staff_boards', 'staff_posts', 'images'];
          for (final col in likely) {
            try {
              final q = await FirebaseFirestore.instance.collection(col).where('complaintId', isEqualTo: id).limit(10).get();
              for (final d in q.docs) {
                photos.addAll(_extractImageStringsFromMap(d.data()));
              }
            } catch (_) {
              // try alternative field names if the first query failed or returned nothing
              try {
                final q2 = await FirebaseFirestore.instance.collection(col).where('complaint_id', isEqualTo: id).limit(10).get();
                for (final d in q2.docs) {
                  photos.addAll(_extractImageStringsFromMap(d.data()));
                }
              } catch (_) {}
            }
            if (photos.isNotEmpty) break;
          }
        }

        // dedupe and normalize
        final uniq = photos.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
        return {'description': desc, 'photos': uniq};
      }
    } catch (e) {
      debugPrint('getComplaintDetails firestore failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (final item in list) {
        try {
          final m = json.decode(item) as Map<String, dynamic>;
          final existingId = (m['id'] ?? m['docId'] ?? '').toString().toUpperCase();
          if (existingId == id.toUpperCase()) {
            final desc = (m['description'] ?? '').toString();
            List<String> photos = [];
            if (m['referencePhotos'] is List) photos = List.from(m['referencePhotos']).map((e) => e.toString()).toList();
            else if (m['photoBase64'] != null) photos = [m['photoBase64'].toString()];
            return {'description': desc, 'photos': photos};
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('getComplaintDetails local failed: $e');
    }

    return {'description': null, 'photos': <String>[]};
  }

  List<String> _extractImageStringsFromMap(Map<String, dynamic> m) {
    final out = <String>[];
    try {
      // check common keys first
      final keys = ['referencePhotos', 'photos', 'photo', 'photoUrl', 'image', 'imageUrl', 'url', 'data', 'photoBase64'];
      for (final k in keys) {
        if (!m.containsKey(k)) continue;
        final v = m[k];
        if (v == null) continue;
        if (v is String) out.add(v);
        else if (v is List) out.addAll(v.map((e) => e.toString()));
      }

      // fallback: scan all string values for data URIs or http links
      for (final entry in m.entries) {
        final v = entry.value;
        if (v is String) {
          final s = v.trim();
          if (s.startsWith('data:image') || s.startsWith('http://') || s.startsWith('https://')) out.add(s);
          // naive base64 detection: long string with '/' '+' and '='
          else if (s.length > 200 && (s.contains('/') || s.contains('+')) && s.contains('=')) out.add(s);
        }
      }
    } catch (_) {}
    return out;
  }

  String _short(String s, [int max = 120]) {
    final trimmed = s.trim();
    if (trimmed.length <= max) return trimmed.isEmpty ? "(no description provided)" : trimmed;
    return '${trimmed.substring(0, max)}...';
  }

  String _maskEmail(String input) {
    try {
      if (!input.contains('@')) return input;
      final parts = input.split('@');
      if (parts.length < 2) return input;
      final local = parts[0];
      final domain = parts.sublist(1).join('@');
      if (local.length <= 3) return '$local@$domain';
      final visible = local.substring(local.length - 3);
      final maskedCount = local.length - 3;
      final stars = List.filled(maskedCount, '*').join();
      final maskedLocal = '$stars$visible';
      return '$maskedLocal@$domain';
    } catch (e) {
      return input;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffE5F1FF),

      appBar: AppBar(
        title: const Text("Railway Assistant"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),

      body: Column(
        children: [
          // Railway theme header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blueAccent],
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8)
              ],
            ),
            child: Column(
              children: const [
                Icon(Icons.train, color: Colors.white, size: 60),
                SizedBox(height: 6),
                Text(
                  "AI Railway Chatbot",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Ask anything related to railway complaints 🚉",
                  style: TextStyle(color: Colors.white70),
                )
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["from"] == "user";
                final typing = (msg["typing"] ?? false) == true;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                      child: typing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 10),
                                Text("Assistant is typing...", style: TextStyle(fontSize: 14, color: Colors.black54)),
                              ],
                            )
                          : (msg["type"] == "image"
                              ? _buildImageMessage(msg["msg"].toString())
                              : _formatMessageText(msg["msg"].toString(), isUser)),
                  ),
                );
              },
            ),
          ),

          // Quick action buttons (three options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  onPressed: _showRealtimeUpdates,
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Real-time updates'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
                ElevatedButton.icon(
                  onPressed: _startKnowledgeBase,
                  icon: const Icon(Icons.book, size: 18),
                  label: const Text('Knowledge base'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _verifyComplaintDialog,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Verify complaint'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
          ),

          // Message Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
