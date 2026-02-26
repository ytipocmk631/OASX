using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Models;
using OASX.WPF.Services;
using System.Collections.ObjectModel;
using System.Text.Json.Nodes;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Overview (dashboard) page of a script.
/// Connects via WebSocket and displays running/pending/waiting tasks plus log.
/// </summary>
public partial class OverviewViewModel : ObservableObject
{
    private readonly ApiService _api;
    private readonly WebSocketService _wsService;
    private WebSocketClient? _wsClient;

    public ScriptModel Script { get; }

    [ObservableProperty]
    private ObservableCollection<string> _logs = [];

    [ObservableProperty]
    private string _wsStatusText = "Disconnected";

    public OverviewViewModel(ScriptModel script, ApiService api, WebSocketService wsService)
    {
        Script = script;
        _api = api;
        _wsService = wsService;
    }

    public async Task ConnectAsync()
    {
        _wsClient = await _wsService.ConnectAsync(
            Script.Name,
            _api.CurrentAddress,
            OnMessage);

        _wsClient.StatusChanged += status =>
        {
            App.Current.Dispatcher.Invoke(() =>
                WsStatusText = status.ToString());
        };
        WsStatusText = _wsClient.Status.ToString();
    }

    private void OnMessage(string message)
    {
        App.Current.Dispatcher.Invoke(() =>
        {
            // Non-JSON messages go straight to the log
            if (!message.StartsWith("{") || !message.EndsWith("}"))
            {
                AppendLog(message);
                return;
            }

            try
            {
                var node = JsonNode.Parse(message);
                if (node is JsonObject obj)
                {
                    // State update: {"state": 0|1|2|3}
                    if (obj["state"] is JsonNode stateNode)
                    {
                        Script.Update(state: (ScriptState)stateNode.GetValue<int>());
                    }

                    // Schedule update: {"schedule": {"running": {...}, "pending": [...], "waiting": [...]}}
                    if (obj["schedule"] is JsonObject schedule)
                    {
                        // Running task
                        TaskItemModel runningTask = new();
                        if (schedule["running"] is JsonObject running &&
                            running["name"]?.ToString() is string runName &&
                            !string.IsNullOrEmpty(runName))
                        {
                            runningTask = new TaskItemModel(
                                runName,
                                running["next_run"]?.ToString() ?? string.Empty);
                        }

                        // Pending list
                        var pendingList = new List<TaskItemModel>();
                        if (schedule["pending"] is JsonArray pending)
                        {
                            pendingList = pending
                                .OfType<JsonObject>()
                                .Select(t => new TaskItemModel(
                                    t["name"]?.ToString() ?? string.Empty,
                                    t["next_run"]?.ToString() ?? string.Empty))
                                .ToList();
                        }

                        // Waiting list
                        var waitingList = new List<TaskItemModel>();
                        if (schedule["waiting"] is JsonArray waiting)
                        {
                            waitingList = waiting
                                .OfType<JsonObject>()
                                .Select(t => new TaskItemModel(
                                    t["name"]?.ToString() ?? string.Empty,
                                    t["next_run"]?.ToString() ?? string.Empty))
                                .ToList();
                        }

                        Script.Update(
                            runningTask: runningTask,
                            pendingTaskList: pendingList,
                            waitingTaskList: waitingList);
                    }
                }
            }
            catch { /* ignore parse errors */ }

            AppendLog(message);
        });
    }

    private void AppendLog(string message)
    {
        Logs.Add($"[{DateTime.Now:HH:mm:ss}] {message}");
        while (Logs.Count > 500)
            Logs.RemoveAt(0);
    }

    [RelayCommand]
    public async Task ToggleScriptAsync()
    {
        if (_wsClient == null) return;
        // Server expects plain string "start" or "stop" (not JSON)
        var action = Script.State == ScriptState.Running ? "stop" : "start";
        await _wsClient.SendAsync(action);
    }

    public async Task DisconnectAsync()
    {
        if (_wsClient != null)
            await _wsService.CloseAsync(Script.Name);
    }
}
