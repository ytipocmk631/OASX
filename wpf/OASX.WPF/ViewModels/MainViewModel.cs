using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Models;
using OASX.WPF.Services;
using System.Collections.ObjectModel;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the main window: manages script list, task menu, and navigation.
/// </summary>
public partial class MainViewModel : ObservableObject
{
    private readonly ApiService _api;
    private readonly WebSocketService _wsService;

    [ObservableProperty]
    private ObservableCollection<string> _scriptNames = [];

    [ObservableProperty]
    private string? _selectedScriptName;

    [ObservableProperty]
    private ScriptModel? _selectedScript;

    [ObservableProperty]
    private object? _currentView;

    [ObservableProperty]
    private ObservableCollection<MenuItemModel> _taskMenuItems = [];

    [ObservableProperty]
    private string? _selectedTask;

    /// <summary>All script models, keyed by name.</summary>
    private readonly Dictionary<string, ScriptModel> _scriptModels = [];

    public OverviewViewModel? OverviewVm { get; private set; }
    public SettingsViewModel SettingsVm { get; }

    private static readonly HashSet<string> OverviewTasks =
        new(StringComparer.OrdinalIgnoreCase) { "Overview", "Home", "Updater", "Tool" };

    public MainViewModel(ApiService api, WebSocketService wsService, SettingsViewModel settingsVm)
    {
        _api = api;
        _wsService = wsService;
        SettingsVm = settingsVm;
    }

    public async Task InitializeAsync()
    {
        var names = await _api.GetConfigListAsync();
        ScriptNames = new ObservableCollection<string>(names);

        if (ScriptNames.Count > 0)
            await SelectScriptInternalAsync(ScriptNames[0]);
    }

    // Called from code-behind when user clicks the script list
    [RelayCommand]
    public async Task SelectScriptAsync(string name)
    {
        await SelectScriptInternalAsync(name);
    }

    private async Task SelectScriptInternalAsync(string name)
    {
        if (SelectedScriptName == name && OverviewVm != null)
            return; // already selected

        SelectedScriptName = name;

        // Disconnect the previous overview before switching
        if (OverviewVm != null)
            await OverviewVm.DisconnectAsync();

        if (!_scriptModels.TryGetValue(name, out var model))
        {
            model = new ScriptModel(name);
            _scriptModels[name] = model;
        }

        SelectedScript = model;
        var overviewVm = new OverviewViewModel(model, _api, _wsService);
        await overviewVm.ConnectAsync();
        OverviewVm = overviewVm;
        OnPropertyChanged(nameof(OverviewVm));

        // Load the task menu for this script
        await LoadTaskMenuAsync(name);

        // Show overview by default
        SelectedTask = "Overview";
        CurrentView = overviewVm;
    }

    private async Task LoadTaskMenuAsync(string scriptName)
    {
        Dictionary<string, List<string>> menu;
        if (string.Equals(scriptName, "Home", StringComparison.OrdinalIgnoreCase))
            menu = await _api.GetHomeMenuAsync();
        else
            menu = await _api.GetScriptMenuAsync();

        var items = new List<MenuItemModel>
        {
            new() { Name = "Overview", IsHeader = false }
        };

        foreach (var (key, values) in menu)
        {
            if (values.Count == 0)
            {
                items.Add(new MenuItemModel { Name = key, IsHeader = false });
            }
            else
            {
                items.Add(new MenuItemModel { Name = key, IsHeader = true });
                foreach (var v in values)
                    items.Add(new MenuItemModel { Name = v, IsHeader = false });
            }
        }

        TaskMenuItems = new ObservableCollection<MenuItemModel>(items);
    }

    /// <summary>Called when user clicks a task in the task-menu panel.</summary>
    public async Task SelectTaskAsync(string taskName)
    {
        SelectedTask = taskName;

        if (OverviewTasks.Contains(taskName))
        {
            // Show the overview/scheduler page
            CurrentView = OverviewVm;
        }
        else if (!string.IsNullOrEmpty(SelectedScriptName) &&
                 !string.Equals(SelectedScriptName, "Home", StringComparison.OrdinalIgnoreCase))
        {
            var argsVm = new ArgsViewModel(_api);
            CurrentView = argsVm; // show loading state immediately
            await argsVm.LoadAsync(SelectedScriptName, taskName);
        }
    }

    [RelayCommand]
    private void ShowAddConfigDialog()
    {
        AddConfigRequested?.Invoke(this, EventArgs.Empty);
    }

    public event EventHandler? AddConfigRequested;

    [RelayCommand]
    private void ShowSettings()
    {
        CurrentView = SettingsVm;
        SelectedTask = null;
    }

    [RelayCommand]
    public async Task DeleteConfigAsync(string deletedScriptName)
    {
        await _api.DeleteConfigAsync(deletedScriptName);
        var names = await _api.GetConfigListAsync();
        ScriptNames = new ObservableCollection<string>(names);

        // If deleted script was selected, switch to first available
        if (SelectedScriptName == deletedScriptName && ScriptNames.Count > 0)
            await SelectScriptInternalAsync(ScriptNames[0]);
    }

    public async Task AddConfigAsync(string newName, string template)
    {
        var names = await _api.ConfigCopyAsync(newName, template);
        ScriptNames = new ObservableCollection<string>(names);
    }

    public async Task RenameConfigAsync(string oldName, string newName)
    {
        await _api.RenameConfigAsync(oldName, newName);
        var names = await _api.GetConfigListAsync();
        ScriptNames = new ObservableCollection<string>(names);
    }

    public async Task<string> GetNewConfigNameAsync() => await _api.GetNewConfigNameAsync();
    public async Task<List<string>> GetConfigAllAsync() => await _api.GetConfigAllAsync();
}
