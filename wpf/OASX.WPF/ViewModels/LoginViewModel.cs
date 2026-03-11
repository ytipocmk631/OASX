using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Services;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Login view.
/// </summary>
public partial class LoginViewModel : ObservableObject
{
    private readonly SettingsService _settings;
    private readonly ApiService _api;

    [ObservableProperty]
    private string _address = string.Empty;

    [ObservableProperty]
    private string _username = string.Empty;

    [ObservableProperty]
    private string _password = string.Empty;

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    [ObservableProperty]
    private bool _isLoading = false;

    public event EventHandler? LoginSucceeded;

    public LoginViewModel(SettingsService settings, ApiService api)
    {
        _settings = settings;
        _api = api;

        Address = settings.Settings.Address;
        Username = settings.Settings.Username;
        Password = settings.Settings.Password;
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        ErrorMessage = string.Empty;

        if (string.IsNullOrWhiteSpace(Address))
        {
            ErrorMessage = "Address cannot be empty.";
            return;
        }

        IsLoading = true;
        try
        {
            _api.SetAddress(Address);
            bool ok = await _api.TestAddressAsync();

            if (ok)
            {
                _settings.UpdateCredentials(Address, Username, Password);
                LoginSucceeded?.Invoke(this, EventArgs.Empty);
            }
            else
            {
                ErrorMessage = "Cannot connect to server. Please check the address.";
            }
        }
        finally
        {
            IsLoading = false;
        }
    }
}
