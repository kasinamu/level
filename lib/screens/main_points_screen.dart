import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/survey_point.dart';
import 'results_screen.dart';
import '../services/storage_service.dart';

class MainPointsScreen extends StatefulWidget {
  const MainPointsScreen({super.key});

  @override
  _MainPointsScreenState createState() => _MainPointsScreenState();
}

class _MainPointsScreenState extends State<MainPointsScreen> {
  final List<MainPoint> _mainPoints = [];

  void _addMainPoint() {
    setState(() {
      final station = _mainPoints.length * 20.0;
      _mainPoints.add(
        MainPoint(
          name: 'No.${_mainPoints.length}',
          station: station,
        ),
      );
    });
  }

  void _navigateToResults() {
    if (_mainPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least two main points to calculate.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          mainPoints: _mainPoints,
          instrumentHeight: 0.0,
          startPointNum: 0,
          endPointNum: _mainPoints.length - 1,
          offsetDirection: OffsetDirection.Center,
          storageService: StorageService(),
          observedReadings: const {},
          completedPoints: const {},
        ),
      ),
    );
  }

  Future<void> _editMainPoint(int index) async {
    final point = _mainPoints[index];
    final formKey = GlobalKey<FormState>();
    final offsetController =
        TextEditingController(text: point.offsetDistance.toString());
    final levelController =
        TextEditingController(text: point.excavationLevel.toString());
    OffsetDirection direction = point.offsetDirection;

    final result = await showDialog<MainPoint>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit ${point.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: offsetController,
                        decoration:
                            const InputDecoration(labelText: 'Offset Distance (m)'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a distance';
                          }
                          return null;
                        },
                      ),
                      DropdownButtonFormField<OffsetDirection>(
                        value: direction,
                        decoration:
                            const InputDecoration(labelText: 'Offset Direction'),
                        items: OffsetDirection.values.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d.name));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              direction = value;
                            });
                          }
                        },
                      ),
                      TextFormField(
                        controller: levelController,
                        decoration:
                            const InputDecoration(labelText: 'Excavation Level'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d*'))
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a level';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final updatedPoint = MainPoint(
                        name: point.name,
                        station: point.station,
                        offsetDistance:
                            double.tryParse(offsetController.text) ??
                                point.offsetDistance,
                        offsetDirection: direction,
                        excavationLevel:
                            double.tryParse(levelController.text) ??
                                point.excavationLevel,
                      );
                      Navigator.of(context).pop(updatedPoint);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _mainPoints[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Main Points'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _navigateToResults,
            tooltip: 'Calculate',
          )
        ],
      ),
      body: _mainPoints.isEmpty
          ? const Center(
              child: Text(
                'Press the + button to add the first main point.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _mainPoints.length,
              itemBuilder: (context, index) {
                final point = _mainPoints[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(point.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Station: ${point.station.toStringAsFixed(1)}m\nOffset: ${point.offsetDistance.toStringAsFixed(3)}m (${point.offsetDirection.name})\nPlan Level: ${point.excavationLevel.toStringAsFixed(3)}'),
                    onTap: () => _editMainPoint(index),
                    trailing: const Icon(Icons.edit, color: Colors.blue),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMainPoint,
        child: const Icon(Icons.add),
        tooltip: 'Add Main Point',
      ),
    );
  }
}
