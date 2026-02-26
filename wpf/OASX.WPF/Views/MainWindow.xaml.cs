using System.Windows;
using System.Windows.Controls;
using OASX.WPF.ViewModels;
using OASX.WPF.Views;

namespace OASX.WPF.Views;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;

    public MainWindow(MainViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;
        vm.SettingsVm.LogoutRequested += OnLogoutRequested;
        vm.AddConfigRequested += OnAddConfigRequested;

        Loaded += async (_, _) => await vm.InitializeAsync();
    }

    private async void ScriptList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (e.AddedItems.Count > 0 && e.AddedItems[0] is string name)
            await _vm.SelectScriptAsync(name);
    }

    private async void OnAddConfigRequested(object? sender, EventArgs e)
    {
        var configAll = await _vm.GetConfigAllAsync();
        var newName = await _vm.GetNewConfigNameAsync();
        var dialog = new AddConfigDialog(newName, configAll) { Owner = this };
        if (dialog.ShowDialog() == true)
            await _vm.AddConfigAsync(dialog.ConfigName, dialog.TemplateName);
    }

    private async void MenuItem_Rename(object sender, RoutedEventArgs e)
    {
        if (_vm.SelectedScriptName == null || _vm.SelectedScriptName == "Home") return;

        var dialog = new RenameDialog(_vm.SelectedScriptName) { Owner = this };
        if (dialog.ShowDialog() == true && !string.IsNullOrWhiteSpace(dialog.NewName))
            await _vm.RenameConfigAsync(_vm.SelectedScriptName, dialog.NewName);
    }

    private async void MenuItem_Delete(object sender, RoutedEventArgs e)
    {
        if (_vm.SelectedScriptName == null || _vm.SelectedScriptName == "Home") return;

        var result = MessageBox.Show(
            $"Delete configuration \"{_vm.SelectedScriptName}\"?",
            "Confirm Delete",
            MessageBoxButton.OKCancel,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.OK)
            await _vm.DeleteConfigAsync(_vm.SelectedScriptName);
    }

    private void OnLogoutRequested(object? sender, EventArgs e)
    {
        var loginWindow = App.CreateLoginWindow();
        loginWindow.Show();
        Close();
    }
}
