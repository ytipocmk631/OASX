using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Services;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Settings view.
/// </summary>
public partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly ApiService _api;

    [ObservableProperty]
    private bool _isDarkTheme;

    [ObservableProperty]
    private bool _isChineseLanguage;

    public event EventHandler? LogoutRequested;
    public event EventHandler<bool>? ThemeChanged;
    public event EventHandler<string>? LanguageChanged;

    public SettingsViewModel(SettingsService settings, ApiService api)
    {
        _settings = settings;
        _api = api;
        _isDarkTheme = settings.Settings.Theme == "Dark";
        _isChineseLanguage = settings.Settings.Language == "zh-CN";
    }

    [RelayCommand]
    private void ToggleTheme()
    {
        IsDarkTheme = !IsDarkTheme;
        var theme = IsDarkTheme ? "Dark" : "Light";
        _settings.UpdateTheme(theme);
        ThemeChanged?.Invoke(this, IsDarkTheme);
    }

    [RelayCommand]
    private void SwitchToChinese()
    {
        IsChineseLanguage = true;
        _settings.UpdateLanguage("zh-CN");
        LanguageChanged?.Invoke(this, "zh-CN");
    }

    [RelayCommand]
    private void SwitchToEnglish()
    {
        IsChineseLanguage = false;
        _settings.UpdateLanguage("en-US");
        LanguageChanged?.Invoke(this, "en-US");
    }

    [RelayCommand]
    private async Task KillServerAsync()
    {
        await _api.KillServerAsync();
    }

    [RelayCommand]
    private void Logout()
    {
        LogoutRequested?.Invoke(this, EventArgs.Empty);
    }
}
