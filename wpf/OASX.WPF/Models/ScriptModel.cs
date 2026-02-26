using CommunityToolkit.Mvvm.ComponentModel;
using System.Collections.ObjectModel;

namespace OASX.WPF.Models;

public enum ScriptState
{
    Inactive = 0,
    Running = 1,
    Warning = 2,
    Updating = 3
}

public class TaskItemModel
{
    public string TaskName { get; set; } = string.Empty;
    public string NextRun { get; set; } = string.Empty;

    public TaskItemModel() { }

    public TaskItemModel(string taskName, string nextRun)
    {
        TaskName = taskName;
        NextRun = nextRun;
    }

    public bool HasNoTaskData => string.IsNullOrEmpty(TaskName) && string.IsNullOrEmpty(NextRun);

    public override string ToString() => string.IsNullOrEmpty(NextRun) ? TaskName : $"{TaskName} ({NextRun})";
}

public partial class ScriptModel : ObservableObject
{
    [ObservableProperty]
    private string _name = string.Empty;

    [ObservableProperty]
    private ScriptState _state = ScriptState.Updating;

    [ObservableProperty]
    private TaskItemModel _runningTask = new();

    public ObservableCollection<TaskItemModel> PendingTaskList { get; } = new();
    public ObservableCollection<TaskItemModel> WaitingTaskList { get; } = new();

    public ScriptModel(string name)
    {
        _name = name;
    }

    public void Update(
        ScriptState? state = null,
        TaskItemModel? runningTask = null,
        List<TaskItemModel>? pendingTaskList = null,
        List<TaskItemModel>? waitingTaskList = null)
    {
        if (state.HasValue) State = state.Value;
        if (runningTask != null) RunningTask = runningTask;
        if (pendingTaskList != null)
        {
            PendingTaskList.Clear();
            foreach (var item in pendingTaskList)
                PendingTaskList.Add(item);
        }
        if (waitingTaskList != null)
        {
            WaitingTaskList.Clear();
            foreach (var item in waitingTaskList)
                WaitingTaskList.Add(item);
        }
    }
}
