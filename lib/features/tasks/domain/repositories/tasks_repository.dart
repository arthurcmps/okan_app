import '../entities/task_item.dart';

abstract class TasksRepository {
  Stream<List<Tarefa>> watchTasks(String userId);

  Future<void> addTask({
    required String userId,
    required String title,
  });

  Future<void> setTaskCompleted({
    required String taskId,
    required bool completed,
  });

  Future<void> deleteTask(String taskId);

  Future<void> restoreTask({
    required String userId,
    required Tarefa task,
  });

  Future<void> updateTitle({
    required String taskId,
    required String title,
  });
}
