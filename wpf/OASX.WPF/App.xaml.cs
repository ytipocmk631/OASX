using System.Globalization;
using System.Net.Http;
using System.Windows;
using System.Windows.Data;
using OASX.WPF.Services;
using OASX.WPF.ViewModels;
using OASX.WPF.Views;

namespace OASX.WPF;

/// <summary>
/// Application entry point. Wires up services and opens the Login window.
/// </summary>
public partial class App : Application
{
    // Shared service instances (manual DI)
    private static SettingsService? _settingsService;
    private static ApiService? _apiService;
    private static WebSocketService? _wsService;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _settingsService = new SettingsService();
        _apiService = new ApiService(new HttpClient());
        _apiService.SetAddress(_settingsService.Settings.Address);
        _wsService = new WebSocketService();

        var loginWindow = CreateLoginWindow();
        loginWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _wsService?.Dispose();
        base.OnExit(e);
    }

    public static LoginWindow CreateLoginWindow()
    {
        var vm = new LoginViewModel(_settingsService!, _apiService!);
        return new LoginWindow(vm);
    }

    public static MainWindow CreateMainWindow()
    {
        var settingsVm = new SettingsViewModel(_settingsService!, _apiService!);
        var mainVm = new MainViewModel(_apiService!, _wsService!, settingsVm);
        return new MainWindow(mainVm);
    }
}

// ===== Value Converters =====

/// <summary>Converts a non-empty string to Visible, empty to Collapsed.</summary>
public class StringToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => string.IsNullOrEmpty(value?.ToString()) ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

/// <summary>Converts bool true to "On", false to "Off".</summary>
public class BoolToOnOffConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => value is true ? "On" : "Off";

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

