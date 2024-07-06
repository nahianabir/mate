import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(prefs: prefs),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final SharedPreferences prefs;

  const MyHomePage({Key? key, required this.prefs}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final _storyController = TextEditingController();
  List<Map<String, String>> _savedStories = [];
  File? _selectedImage;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isGridMode = true; // Default to grid view mode
  TextEditingController _searchController = TextEditingController();
  bool _isAddingNewStory = false; // Track if adding a new story

  @override
  void initState() {
    super.initState();
    _loadSavedStories();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 0.2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadSavedStories() async {
    final prefs = widget.prefs;
    final allKeys = prefs.getKeys();
    _savedStories = [];
    for (var key in allKeys) {
      final story = prefs.getString(key);
      if (story != null) {
        final storyData = story.split('|');
        _savedStories.add({
          'date': storyData[0],
          'text': storyData[1],
          'image': storyData.length > 2 ? storyData[2] : '',
          'pinned': storyData.length > 3 ? storyData[3] : 'false', // Check if story is pinned
          'isEditing': 'false',
        });
      }
    }
    setState(() {});
  }

  Future<void> _saveStory(BuildContext context, {String? keyToUpdate}) async {
    final story = _storyController.text;
    if (story.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a story!')),
      );
      return;
    }

    final prefs = widget.prefs;
    final key = keyToUpdate ?? DateTime.now().toIso8601String();
    final imagePath = _selectedImage?.path ?? '';
    final pinned = keyToUpdate != null
        ? _savedStories
        .firstWhere((story) => story['date'] == key)['pinned']!
        : 'false';
    await prefs.setString(
        key, '${DateTime.now().toIso8601String()}|$story|$imagePath|$pinned');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story saved successfully!')),
    );
    _storyController.clear();
    _selectedImage = null;
    _isAddingNewStory = false; // Stop adding new story
    _loadSavedStories();
  }

  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _deleteStory(int index) async {
    final prefs = widget.prefs;
    final story = _savedStories[index];
    final key = prefs.getKeys().firstWhere((k) =>
    prefs.getString(k) ==
        '${story['date']}|${story['text']}|${story['image']}|${story['pinned']}');
    await prefs.remove(key);
    _savedStories.removeAt(index);
    setState(() {});
  }

  void _editStory(int index) {
    final story = _savedStories[index];
    setState(() {
      story['isEditing'] = 'true';
    });
  }

  void _cancelEditStory(int index) {
    final story = _savedStories[index];
    setState(() {
      story['isEditing'] = 'false';
    });
  }

  Future<void> _saveEditedStory(int index) async {
    final story = _savedStories[index];
    final updatedText = story['text']!;
    final key = story['date']!;

    final prefs = widget.prefs;
    final imagePath = _selectedImage?.path ?? '';
    final pinned = story['pinned']!;
    await prefs.setString(
        key, '${story['date']}|$updatedText|$imagePath|$pinned');

    setState(() {
      story['isEditing'] = 'false';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story updated successfully!')),
    );
    _loadSavedStories();
  }

  void _pinStory(int index) async {
    final prefs = widget.prefs;
    final story = _savedStories[index];
    final updatedPinnedStatus =
    story['pinned'] == 'true' ? 'false' : 'true';
    await prefs.setString(
        story['date']!,
        '${story['date']}|${story['text']}|${story['image']}|$updatedPinnedStatus');
    _loadSavedStories();
  }

  void _filterStories(String query) {
    if (query.isEmpty) {
      _loadSavedStories(); // Reset list to all stories
    } else {
      final filteredList = _savedStories.where((story) =>
      story['text']!.toLowerCase().contains(query.toLowerCase()) ||
          story['date']!.toLowerCase().contains(query.toLowerCase()));
      setState(() {
        _savedStories = filteredList.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Stories',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _filterStories(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3 / 4, // Adjust the aspect ratio
                  ),
                  itemCount:
                  _isAddingNewStory ? _savedStories.length + 1 : _savedStories.length,
                  itemBuilder: (context, index) {
                    if (_isAddingNewStory && index == 0) {
                      return _buildNewStoryCard();
                    } else {
                      return _buildStoryCard(
                          _isAddingNewStory ? index - 1 : index);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isAddingNewStory = true;
          });
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  Widget _buildNewStoryCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: Colors.white.withOpacity(0.3), // Adjust transparency here
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImage != null)
              Image.file(
                _selectedImage!,
                width: double.infinity,
                height: 100,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 4),
            Expanded(
              child: TextField(
                controller: _storyController,
                style: TextStyle(fontSize: 14),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Enter your story...',
                  border: InputBorder.none,
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _pickImage,
                  color: Colors.black,
                ),
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () => _saveStory(context),
                  color: Colors.black,
                ),
                IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      _isAddingNewStory = false;
                      _storyController.clear();
                      _selectedImage = null;
                    });
                  },
                  color: Colors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(int index) {
    final story = _savedStories[index];
    bool isEditing = story['isEditing'] == 'true';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: Colors.white.withOpacity(0.3), // Adjust transparency here
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (story['image']!.isNotEmpty)
              Image.file(
                File(story['image']!),
                width: double.infinity,
                height: 100,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 4),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: isEditing
                        ? TextField(
                      controller:
                      TextEditingController(text: story['text']),
                      style: TextStyle(fontSize: 14),
                      maxLines: null,
                      onChanged: (value) {
                        story['text'] = value;
                      },
                    )
                        : AnimatedBuilder(
                      animation: _offsetAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: _offsetAnimation.value,
                          child: Text(
                            story['text']!,
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.left,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(story['pinned'] == 'true'
                      ? Icons.push_pin
                      : Icons.push_pin_outlined),
                  onPressed: () => _pinStory(index),
                  color: Colors.black,
                ),
                IconButton(
                  icon: Icon(isEditing ? Icons.check : Icons.edit),
                  onPressed: () =>
                  isEditing ? _saveEditedStory(index) : _editStory(index),
                  color: Colors.black,
                ),
                if (isEditing)
                  IconButton(
                    icon: Icon(Icons.cancel),
                    onPressed: () => _cancelEditStory(index),
                    color: Colors.black,
                  ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteStory(index),
                  color: Colors.black,
                ),
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () => Share.share(story['text']!),
                  color: Colors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

