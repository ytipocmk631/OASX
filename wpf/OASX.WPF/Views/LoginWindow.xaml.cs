using System.Windows;
using OASX.WPF.ViewModels;

namespace OASX.WPF.Views;

public partial class LoginWindow : Window
{
    private readonly LoginViewModel _vm;

    public LoginWindow(LoginViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;
        vm.LoginSucceeded += OnLoginSucceeded;
    }

    private void PasswordBox_PasswordChanged(object sender, RoutedEventArgs e)
    {
        _vm.Password = PasswordBox.Password;
    }

    private void OnLoginSucceeded(object? sender, EventArgs e)
    {
        var mainWindow = App.CreateMainWindow();
        mainWindow.Show();
        Close();
    }
}
