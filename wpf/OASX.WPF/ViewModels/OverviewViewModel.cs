using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Models;
using OASX.WPF.Services;
using System.Collections.ObjectModel;
using System.Text.Json;
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
            try
            {
                var node = JsonNode.Parse(message);
                if (node is JsonObject obj)
                {
                    // Parse script state
                    if (obj["state"] != null)
                    {
                        var stateVal = obj["state"]!.GetValue<int>();
                        Script.Update(state: (ScriptState)stateVal);
                    }

                    // Parse running task
                    if (obj["running"] is JsonObject running)
                    {
                        Script.Update(runningTask: new TaskItemModel(
                            running["id"]?.ToString() ?? "",
                            running["task"]?.ToString() ?? ""));
                    }

                    // Parse pending list
                    if (obj["pending"] is JsonArray pending)
                    {
                        Script.Update(pendingTaskList: pending
                            .Select(t => new TaskItemModel(
                                t?["id"]?.ToString() ?? "",
                                t?["task"]?.ToString() ?? ""))
                            .ToList());
                    }

                    // Parse waiting list
                    if (obj["waiting"] is JsonArray waiting)
                    {
                        Script.Update(waitingTaskList: waiting
                            .Select(t => new TaskItemModel(
                                t?["id"]?.ToString() ?? "",
                                t?["task"]?.ToString() ?? ""))
                            .ToList());
                    }
                }

                // Append raw message to log (keep last 500 lines)
                Logs.Add($"[{DateTime.Now:HH:mm:ss}] {message}");
                while (Logs.Count > 500)
                    Logs.RemoveAt(0);
            }
            catch
            {
                Logs.Add($"[{DateTime.Now:HH:mm:ss}] {message}");
            }
        });
    }

    [RelayCommand]
    public async Task ToggleScriptAsync()
    {
        if (_wsClient == null) return;
        var action = Script.State == ScriptState.Running ? "stop" : "start";
        await _wsClient.SendAsync(JsonSerializer.Serialize(new { action }));
    }

    public async Task DisconnectAsync()
    {
        if (_wsClient != null)
            await _wsService.CloseAsync(Script.Name);
    }
}
