using System.ComponentModel;
using System.Windows.Controls;
using OASX.WPF.ViewModels;

namespace OASX.WPF.Views;

public partial class UpdaterView : UserControl
{
    private UpdaterViewModel? _vm;

    public UpdaterView()
    {
        InitializeComponent();
        DataContextChanged += (_, e) =>
        {
            if (_vm != null) _vm.PropertyChanged -= OnVmPropertyChanged;
            _vm = e.NewValue as UpdaterViewModel;
            if (_vm != null)
            {
                _vm.PropertyChanged += OnVmPropertyChanged;
                if (!_vm.IsLoading) BuildCommitHistory(_vm);
            }
        };
    }

    private void OnVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(UpdaterViewModel.IsLoading) && _vm != null && !_vm.IsLoading)
            Dispatcher.Invoke(() => BuildCommitHistory(_vm));
    }

    private void BuildCommitHistory(UpdaterViewModel vm)
    {
        var lines = vm.CommitHistory
            .Select(c => c.Count >= 4
                ? $"{c[0][..Math.Min(7, c[0].Length)]}  {c[1]}  {c[2]}  {c[3]}"
                : string.Join("  ", c))
            .ToList();
        CommitHistoryList.ItemsSource = lines;
    }
}
