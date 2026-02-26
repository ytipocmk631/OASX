using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OASX.WPF.Models;
using OASX.WPF.ViewModels;

namespace OASX.WPF.Views;

public partial class ArgsView : UserControl
{
    private ArgsViewModel? _vm;

    public ArgsView()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (_vm != null)
            _vm.PropertyChanged -= OnVmPropertyChanged;

        _vm = e.NewValue as ArgsViewModel;

        if (_vm != null)
        {
            _vm.PropertyChanged += OnVmPropertyChanged;
            if (!_vm.IsLoading)
                BuildArgUI(_vm);
        }
    }

    private void OnVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ArgsViewModel.IsLoading) && _vm != null && !_vm.IsLoading)
            Dispatcher.Invoke(() => BuildArgUI(_vm));
    }

    // -------------------------------------------------------------------------
    // Build the argument UI dynamically based on group/arg data
    // -------------------------------------------------------------------------
    private void BuildArgUI(ArgsViewModel vm)
    {
        ArgsContainer.Children.Clear();

        if (vm.Groups.Count == 0)
        {
            ArgsContainer.Children.Add(new TextBlock
            {
                Text = Services.LocalizationService.Instance.Translate("No arguments available."),
                Foreground = Brushes.Gray,
                Margin = new Thickness(0, 20, 0, 0),
                FontSize = 13
            });
            return;
        }

        foreach (var group in vm.Groups)
        {
            var expander = BuildGroupExpander(group, vm);
            ArgsContainer.Children.Add(expander);
        }
    }

    private static Expander BuildGroupExpander(ArgGroupModel group, ArgsViewModel vm)
    {
        var panel = new StackPanel { Margin = new Thickness(4, 0, 4, 4) };

        foreach (var arg in group.Members)
        {
            var row = BuildArgRow(arg, group.GroupName, vm);
            panel.Children.Add(row);
        }

        return new Expander
        {
            Header = string.IsNullOrEmpty(group.TranslatedGroupName) ? group.GroupName : group.TranslatedGroupName,
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            IsExpanded = true,
            Content = panel,
            Margin = new Thickness(0, 0, 0, 10),
        };
    }

    private static UIElement BuildArgRow(ArgModel arg, string groupName, ArgsViewModel vm)
    {
        var grid = new Grid { Margin = new Thickness(0, 5, 0, 5) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });

        // Left: label + description
        var labelPanel = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var displayName = string.IsNullOrEmpty(arg.TranslatedName) ? arg.Name : arg.TranslatedName;
        labelPanel.Children.Add(new TextBlock
        {
            Text = displayName,
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap
        });
        var displayDesc = string.IsNullOrEmpty(arg.TranslatedDescription) ? arg.Description : arg.TranslatedDescription;
        if (!string.IsNullOrWhiteSpace(displayDesc))
        {
            labelPanel.Children.Add(new TextBlock
            {
                Text = displayDesc,
                FontSize = 11,
                Foreground = (System.Windows.Media.Brush)Application.Current.Resources["SecondaryForegroundBrush"],
                TextWrapping = TextWrapping.Wrap
            });
        }
        Grid.SetColumn(labelPanel, 0);
        grid.Children.Add(labelPanel);

        // Right: editor control
        var editor = BuildEditor(arg, groupName, vm);
        Grid.SetColumn(editor, 1);
        grid.Children.Add(editor);

        return grid;
    }

    private static UIElement BuildEditor(ArgModel arg, string groupName, ArgsViewModel vm)
    {
        switch (arg.Type)
        {
            case "boolean":
            {
                var cb = new CheckBox
                {
                    IsChecked = arg.Value is bool b ? b : string.Equals(arg.Value?.ToString(), "true", StringComparison.OrdinalIgnoreCase),
                    VerticalAlignment = VerticalAlignment.Center
                };
                cb.Checked   += (_, _) => vm.SetArgDebounced(groupName, arg, true);
                cb.Unchecked += (_, _) => vm.SetArgDebounced(groupName, arg, false);
                return cb;
            }

            case "enum":
            {
                var combo = new ComboBox
                {
                    ItemsSource = arg.EnumOptions,
                    SelectedItem = arg.Value?.ToString(),
                    Width = 200,
                    HorizontalAlignment = HorizontalAlignment.Left
                };
                combo.SelectionChanged += (_, e) =>
                {
                    if (e.AddedItems.Count > 0)
                        vm.SetArgDebounced(groupName, arg, e.AddedItems[0]);
                };
                return combo;
            }

            case "integer":
            case "number":
            {
                var tb = new TextBox
                {
                    Text = arg.Value?.ToString() ?? string.Empty,
                    Width = 200,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(4, 3, 4, 3)
                };
                tb.TextChanged += (_, _) => vm.SetArgDebounced(groupName, arg, tb.Text);
                return tb;
            }

            case "multi_line":
            {
                var tb = new TextBox
                {
                    Text = arg.Value?.ToString() ?? string.Empty,
                    Width = 200,
                    MinHeight = 60,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    TextWrapping = TextWrapping.Wrap,
                    AcceptsReturn = true,
                    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                    Padding = new Thickness(4, 3, 4, 3)
                };
                tb.TextChanged += (_, _) => vm.SetArgDebounced(groupName, arg, tb.Text);
                return tb;
            }

            default: // string, date_time, time, time_delta, etc.
            {
                var tb = new TextBox
                {
                    Text = arg.Value?.ToString() ?? string.Empty,
                    Width = 200,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(4, 3, 4, 3)
                };
                tb.TextChanged += (_, _) => vm.SetArgDebounced(groupName, arg, tb.Text);
                return tb;
            }
        }
    }
}
