using CommunityToolkit.Mvvm.ComponentModel;
using OASX.WPF.Models;
using OASX.WPF.Services;
using System.Collections.ObjectModel;
using System.Text.Json.Nodes;
using System.Windows;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the task-argument configuration page.
/// Loads args from the API, tracks per-arg debounced saves back to the API.
/// </summary>
public partial class ArgsViewModel : ObservableObject
{
    private readonly ApiService _api;
    private string _scriptName = string.Empty;
    private string _taskName = string.Empty;

    // Key: "groupName/argName" -> active debounce timer
    private readonly Dictionary<string, Timer> _debouncers = [];

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private string _title = string.Empty;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    public ObservableCollection<ArgGroupModel> Groups { get; } = [];

    public ArgsViewModel(ApiService api) => _api = api;

    public async Task LoadAsync(string scriptName, string taskName)
    {
        _scriptName = scriptName;
        _taskName = taskName;
        Title = LocalizationService.Instance.Translate(taskName);
        StatusMessage = string.Empty;
        IsLoading = true;
        Groups.Clear();

        try
        {
            var json = await _api.GetScriptTaskArgsAsync(scriptName, taskName);
            if (json == null)
            {
                StatusMessage = LocalizationService.Instance.Translate("Failed to load arguments.");
                return;
            }

            foreach (var (groupName, groupNode) in json)
            {
                var members = new List<ArgModel>();
                if (groupNode is JsonArray arr)
                {
                    foreach (var item in arr)
                    {
                        if (item is JsonObject obj)
                            members.Add(ParseArg(groupName, obj));
                    }
                }
                var translatedGroupName = LocalizationService.Instance.Translate(groupName);
                Groups.Add(new ArgGroupModel { GroupName = groupName, TranslatedGroupName = translatedGroupName, Members = members });
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    private ArgModel ParseArg(string groupName, JsonObject obj)
    {
        var type = obj["type"]?.ToString() ?? "string";
        var valueNode = obj["value"];

        object? value = type switch
        {
            "boolean" => valueNode?.GetValue<bool>() ?? false,
            _ => valueNode?.ToString() ?? string.Empty
        };

        List<string> enumOptions = [];
        if (obj["enumEnum"] is JsonArray enumArr)
            enumOptions = enumArr.Select(e => e?.ToString() ?? string.Empty).ToList();

        var rawName = obj["name"]?.ToString() ?? string.Empty;
        var rawDesc = obj["description"]?.ToString();

        var arg = new ArgModel
        {
            Name = rawName,
            TranslatedName = LocalizationService.Instance.Translate(rawName),
            Type = type,
            Description = rawDesc,
            TranslatedDescription = rawDesc == null ? null : LocalizationService.Instance.Translate(rawDesc),
            Value = value,
            EnumOptions = enumOptions,
        };

        // Wire save-callback with 1-second debounce
        arg.SaveCallback = newVal => SetArgDebouncedAsync(groupName, arg, newVal);
        return arg;
    }

    /// <summary>
    /// Called from ArgsView code-behind when user changes a value.
    /// Updates the model immediately and schedules an API save after 1 second of inactivity.
    /// </summary>
    public void SetArgDebounced(string groupName, ArgModel arg, object? value)
    {
        arg.Value = value;

        var key = $"{groupName}/{arg.Name}";
        if (_debouncers.TryGetValue(key, out var existing))
            existing.Dispose();

        // Run cleanup + API call on the UI thread to avoid dict race conditions
        _debouncers[key] = new Timer(_ =>
        {
            Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                if (_debouncers.TryGetValue(key, out var t))
                {
                    _debouncers.Remove(key);
                    t.Dispose();
                }
                var saved = await _api.PutScriptArgAsync(
                    _scriptName, _taskName, groupName, arg.Name, arg.Type, value ?? string.Empty);
                StatusMessage = saved
                    ? $"Saved: {arg.Name}"
                    : $"Save failed: {arg.Name}";
            });
        }, null, TimeSpan.FromSeconds(1), Timeout.InfiniteTimeSpan);
    }

    private Task SetArgDebouncedAsync(string groupName, ArgModel arg, object? value)
    {
        SetArgDebounced(groupName, arg, value);
        return Task.CompletedTask;
    }
}
