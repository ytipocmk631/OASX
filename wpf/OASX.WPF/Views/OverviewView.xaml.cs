using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;
using OASX.WPF.ViewModels;

namespace OASX.WPF.Views;

public partial class OverviewView : UserControl
{
    private NotifyCollectionChangedEventHandler? _logsChangedHandler;

    public OverviewView()
    {
        InitializeComponent();

        DataContextChanged += (_, e) =>
        {
            // Unregister from the old ViewModel
            if (e.OldValue is OverviewViewModel oldVm && _logsChangedHandler != null)
                oldVm.Logs.CollectionChanged -= _logsChangedHandler;

            // Register on the new ViewModel
            if (e.NewValue is OverviewViewModel newVm)
            {
                _logsChangedHandler = (_, _) => LogScrollViewer.ScrollToBottom();
                newVm.Logs.CollectionChanged += _logsChangedHandler;
            }
        };
    }

    private void ClearLog_Click(object sender, RoutedEventArgs e)
    {
        if (DataContext is OverviewViewModel vm)
            vm.Logs.Clear();
    }
}
