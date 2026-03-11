using System.Windows;
using System.Windows.Controls;
using OASX.WPF.ViewModels;

namespace OASX.WPF.Views;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;
    // Prevents double-firing when InitializeAsync sets SelectedScriptName programmatically
    private bool _suppressSelectionChange = false;
    // Prevents spurious SelectTaskAsync calls when task list is repopulated during script switching
    private bool _suppressTaskSelectionChange = false;

    public MainWindow(MainViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;
        vm.SettingsVm.LogoutRequested += OnLogoutRequested;
        vm.AddConfigRequested += OnAddConfigRequested;

        Loaded += async (_, _) =>
        {
            _suppressSelectionChange = true;
            _suppressTaskSelectionChange = true;
            try { await vm.InitializeAsync(); }
            finally
            {
                _suppressSelectionChange = false;
                _suppressTaskSelectionChange = false;
            }
        };
    }

    private async void ScriptList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressSelectionChange) return;
        if (e.AddedItems.Count > 0 && e.AddedItems[0] is string name)
        {
            _suppressTaskSelectionChange = true;
            try { await _vm.SelectScriptAsync(name); }
            finally { _suppressTaskSelectionChange = false; }
        }
    }

    private async void TaskList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressTaskSelectionChange) return;
        if (e.AddedItems.Count > 0 && e.AddedItems[0] is Models.MenuItemModel item && !item.IsHeader)
            await _vm.SelectTaskAsync(item.Name);
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
        // Use the item the context menu was opened on, not just SelectedScriptName
        var name = GetContextMenuTargetScript() ?? _vm.SelectedScriptName;
        if (name == null || name == "Home") return;

        var dialog = new RenameDialog(name) { Owner = this };
        if (dialog.ShowDialog() == true && !string.IsNullOrWhiteSpace(dialog.NewName))
            await _vm.RenameConfigAsync(name, dialog.NewName);
    }

    private async void MenuItem_Delete(object sender, RoutedEventArgs e)
    {
        var name = GetContextMenuTargetScript() ?? _vm.SelectedScriptName;
        if (name == null || name == "Home") return;

        var result = MessageBox.Show(
            $"Delete configuration \"{name}\"?",
            "Confirm Delete",
            MessageBoxButton.OKCancel,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.OK)
            await _vm.DeleteConfigAsync(name);
    }

    /// <summary>
    /// Attempts to find which script name the ListBox context menu was opened for.
    /// Returns null if it cannot be determined.
    /// </summary>
    private string? GetContextMenuTargetScript()
    {
        // WPF ContextMenu stores the PlacementTarget (the ListBox itself);
        // we figure out which item it was opened on via the ListBox's SelectedItem.
        return ScriptListBox.SelectedItem as string;
    }

    private void OnLogoutRequested(object? sender, EventArgs e)
    {
        var loginWindow = App.CreateLoginWindow();
        loginWindow.Show();
        Close();
    }
}

