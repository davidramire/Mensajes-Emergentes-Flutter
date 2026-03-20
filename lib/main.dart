import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  await NotificationService.initialize();
  runApp(const GestorTareasApp());
}

// ========== SERVICIO DE NOTIFICACIONES ==========
class NotificationService {
  static int _notificationId = 0;

  static Future<void> initialize() async {
    // Solicitar permiso de notificaciones
    await _requestNotificationPermission();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación recibida: ${response.payload}');
      },
    );
  }

  static Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    debugPrint('Estado permiso notificaciones: $status');
  }

  static Future<void> showNotification(String title, String body) async {
    _notificationId++;
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'tasks_channel',
      'Notificaciones de Tareas',
      channelDescription: 'Notificaciones de nuevas tareas',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        _notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: title,
      );
      debugPrint('Notificación mostrada: ID $_notificationId');
    } catch (e) {
      debugPrint('Error al mostrar notificación: $e');
    }
  }

  static Future<void> scheduleNotification(
    String title,
    String body,
    Duration delay,
  ) async {
    _notificationId++;
    final notificationId = _notificationId;
    
    debugPrint('⏰ Notificación programada para $delay - ID: $notificationId');
    
    // Usar Future.delayed para que funcione en background
    Future.delayed(delay, () async {
      try {
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'tasks_channel',
          'Notificaciones de Tareas',
          channelDescription: 'Notificaciones de nuevas tareas',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );

        const DarwinNotificationDetails iOSPlatformChannelSpecifics =
            DarwinNotificationDetails();

        const NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics,
        );

        await flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          platformChannelSpecifics,
          payload: title,
        );
        
        debugPrint('✅ Recordatorio enviado: ID $notificationId');
      } catch (e) {
        debugPrint('❌ Error al enviar recordatorio: $e');
      }
    });
  }
}

// ========== APP PRINCIPAL ==========
class GestorTareasApp extends StatelessWidget {
  const GestorTareasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Tareas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TasksPage(),
    );
  }
}

// ========== PÁGINA DE TAREAS ==========
class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final List<Task> tasks = [];
  final TextEditingController taskController = TextEditingController();
  late SharedPreferences prefs;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    await loadTasks();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveTasks() async {
    final tasksList = tasks.map((task) => task.toJson()).toList();
    await prefs.setString('tasks', jsonEncode(tasksList));
    debugPrint('✅ Tareas guardadas: ${tasks.length}');
  }

  Future<void> loadTasks() async {
    try {
      final tasksJson = prefs.getString('tasks');
      if (tasksJson != null) {
        final decoded = jsonDecode(tasksJson) as List;
        setState(() {
          tasks.clear();
          tasks.addAll(decoded.map((task) => Task.fromJson(task)).toList());
        });
        debugPrint('✅ Tareas cargadas: ${tasks.length}');
      }
    } catch (e) {
      debugPrint('❌ Error al cargar tareas: $e');
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Agregar Tarea'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Descripción de la tarea',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El campo no puede estar vacío'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                addTask(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void addTask(String title) {
    final newTask = Task(id: DateTime.now().toString(), title: title);
    setState(() {
      tasks.add(newTask);
    });
    saveTasks();

    NotificationService.showNotification(title, 'Tienes una tarea pendiente');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tarea añadida'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            setState(() {
              tasks.removeWhere((t) => t.id == newTask.id);
            });
            saveTasks();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void toggleTask(String id) {
    setState(() {
      final task = tasks.firstWhere((t) => t.id == id);
      task.isCompleted = !task.isCompleted;
    });
    saveTasks();

    final task = tasks.firstWhere((t) => t.id == id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(task.isCompleted ? 'Tarea completada' : 'Tarea pendiente'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTaskOptions(String id, String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Completar'),
              onTap: () {
                Navigator.pop(context);
                toggleTask(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Recordarme'),
              onTap: () {
                Navigator.pop(context);
                NotificationService.scheduleNotification(
                  title,
                  'Tienes una tarea pendiente',
                  const Duration(minutes: 1),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recordatorio programado para 1 minuto'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: const Text('¿Estás seguro de que deseas eliminar esta tarea?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final task = tasks.firstWhere((t) => t.id == id);
              setState(() {
                tasks.removeWhere((t) => t.id == id);
              });
              saveTasks();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Tarea eliminada'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      setState(() {
                        tasks.add(task);
                      });
                      saveTasks();
                    },
                  ),
                ),
              );

              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestor de Tareas'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor de Tareas'),
        elevation: 0,
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.checklist,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay tareas',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pulsa + para agregar una',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return GestureDetector(
                  onLongPress: () => _showTaskOptions(task.id, task.title),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (_) => toggleTask(task.id),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.isCompleted
                            ? Colors.grey[500]
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Agregar tarea',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }
}

// ========== MODELO DE TAREA ==========
class Task {
  final String id;
  String title;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  // Convertir Task a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  // Convertir JSON a Task
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}