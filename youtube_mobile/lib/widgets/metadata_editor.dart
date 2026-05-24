import 'package:flutter/material.dart';
import '../models/video_job.dart';

class MetadataEditor extends StatefulWidget {
  final VideoJob job;
  const MetadataEditor({super.key, required this.job});

  @override
  State<MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<MetadataEditor> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _authorController = TextEditingController(text: widget.job.author);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: const BoxDecoration(
          color: Color(0xff121820),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          border: Border(
            top: BorderSide(color: Color(0xff00d2ff), width: 1.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "EDIT ARCHIVE TAGS",
              style: TextStyle(
                color: Color(0xff00d2ff),
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Title",
                labelStyle: TextStyle(color: Colors.blueGrey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueGrey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xff00ff88)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Author / Lecturer",
                labelStyle: TextStyle(color: Colors.blueGrey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueGrey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xff00ff88)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0a0d14),
                    foregroundColor: const Color(0xff00ff88),
                    side: const BorderSide(color: Color(0xff00ff88), width: 1.0),
                  ),
                  onPressed: () {
                    setState(() {
                      widget.job.title = _titleController.text.trim();
                      widget.job.author = _authorController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Media tags successfully customized offline."),
                        backgroundColor: Color(0xff00ff88),
                      ),
                    );
                  },
                  child: const Text("SAVE TAGS"),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
