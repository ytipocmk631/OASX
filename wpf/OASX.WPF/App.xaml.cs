using System.Globalization;
using System.Net.Http;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
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

        // Apply saved theme on startup
        ApplyTheme(_settingsService.Settings.Theme == "Dark");

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
        settingsVm.ThemeChanged += (_, isDark) => ApplyTheme(isDark);
        var mainVm = new MainViewModel(_apiService!, _wsService!, settingsVm);
        return new MainWindow(mainVm);
    }

    /// <summary>
    /// Swaps the application-level brush resources to implement light/dark theming.
    /// Uses DynamicResource references in XAML so all controls update automatically.
    /// </summary>
    public static void ApplyTheme(bool isDark)
    {
        var res = Current.Resources;
        if (isDark)
        {
            res["BackgroundBrush"]          = new SolidColorBrush(Color.FromRgb(30,  30,  30));
            res["SidebarBrush"]             = new SolidColorBrush(Color.FromRgb(45,  45,  45));
            res["ForegroundBrush"]          = new SolidColorBrush(Color.FromRgb(220, 220, 220));
            res["SecondaryForegroundBrush"] = new SolidColorBrush(Color.FromRgb(160, 160, 160));
            res["CardBackground"]           = new SolidColorBrush(Color.FromRgb(50,  50,  50));
        }
        else
        {
            res["BackgroundBrush"]          = new SolidColorBrush(Colors.White);
            res["SidebarBrush"]             = new SolidColorBrush(Color.FromRgb(238, 238, 238));
            res["ForegroundBrush"]          = new SolidColorBrush(Color.FromRgb(33,  33,  33));
            res["SecondaryForegroundBrush"] = new SolidColorBrush(Color.FromRgb(85,  85,  85));
            res["CardBackground"]           = new SolidColorBrush(Colors.White);
        }
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

