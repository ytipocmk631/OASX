using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Services;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Tool page (Home → Tool).
/// Provides a notification-test form that POSTs to /home/notify_test.
/// </summary>
public partial class ToolViewModel : ObservableObject
{
    private readonly ApiService _api;

    [ObservableProperty] private string _testConfig = "provider:";
    [ObservableProperty] private string _testTitle = "Title";
    [ObservableProperty] private string _testContent = "Content";
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _isSending;

    public ToolViewModel(ApiService api) => _api = api;

    [RelayCommand]
    private async Task SendTestAsync()
    {
        IsSending = true;
        StatusMessage = string.Empty;
        try
        {
            bool ok = await _api.NotifyTestAsync(TestConfig, TestTitle, TestContent);
            StatusMessage = ok ? "Notification sent successfully." : "Notification test failed.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsSending = false;
        }
    }
}
