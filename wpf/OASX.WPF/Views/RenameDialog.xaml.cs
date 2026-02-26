using System.Windows;
using System.Windows.Input;

namespace OASX.WPF.Views;

public partial class RenameDialog : Window
{
    public string NewName { get; set; }

    private readonly string _originalName;

    public RenameDialog(string currentName)
    {
        InitializeComponent();
        _originalName = currentName;
        NewName = currentName;
        DataContext = this;
        NameBox.SelectAll();
        NameBox.Focus();
    }

    private void OK_Click(object sender, RoutedEventArgs e)
    {
        if (!Validate()) return;
        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
    }

    private void NameBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) OK_Click(sender, e);
    }

    private bool Validate()
    {
        if (string.IsNullOrWhiteSpace(NewName))
        {
            ErrorLabel.Text = "Name cannot be empty.";
            return false;
        }
        if (NewName == _originalName)
        {
            ErrorLabel.Text = "Name has not changed.";
            return false;
        }
        ErrorLabel.Text = string.Empty;
        return true;
    }
}
