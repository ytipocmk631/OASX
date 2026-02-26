using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Models;
using OASX.WPF.Services;
using System.Collections.ObjectModel;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the main window: manages script list and navigation.
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

    /// <summary>All script models, keyed by name.</summary>
    private readonly Dictionary<string, ScriptModel> _scriptModels = [];

    public OverviewViewModel? OverviewVm { get; private set; }
    public SettingsViewModel SettingsVm { get; }

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
            await SelectScriptAsync(ScriptNames[0]);
    }

    [RelayCommand]
    public async Task SelectScriptAsync(string name)
    {
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
        CurrentView = overviewVm;
        OnPropertyChanged(nameof(OverviewVm));
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
    }

    [RelayCommand]
    public async Task DeleteConfigAsync(string name)
    {
        await _api.DeleteConfigAsync(name);
        var names = await _api.GetConfigListAsync();
        ScriptNames = new ObservableCollection<string>(names);
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
