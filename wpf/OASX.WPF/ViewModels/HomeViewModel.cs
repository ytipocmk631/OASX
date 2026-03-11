namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Home page (shown when "Home" script is selected and "Home" task is active).
/// </summary>
public class HomeViewModel
{
    public string WelcomeText { get; } = "Welcome to OASX";
    public string SubText { get; } = "Select a script from the left panel, or use the task menu above to access Updater and notification tools.";
}
