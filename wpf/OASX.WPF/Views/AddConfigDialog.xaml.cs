using CommunityToolkit.Mvvm.ComponentModel;
using System.Collections.ObjectModel;
using System.Windows;

namespace OASX.WPF.Views;

public partial class AddConfigDialog : Window
{
    public string ConfigName { get; set; }
    public string TemplateName { get; set; }
    public List<string> Templates { get; }

    public AddConfigDialog(string suggestedName, List<string> templates)
    {
        InitializeComponent();
        ConfigName = suggestedName;
        Templates = templates;
        TemplateName = templates.Count > 0 ? templates[0] : "template";
        DataContext = this;
        NameBox.Focus();
        NameBox.SelectAll();
    }

    private void OK_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(ConfigName))
        {
            ErrorLabel.Text = "Name cannot be empty.";
            return;
        }
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }
}
