using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using OASX.WPF.Models;
using OASX.WPF.Services;

namespace OASX.WPF.ViewModels;

/// <summary>
/// ViewModel for the Updater page (Home → Updater).
/// Fetches update info from /home/update_info and triggers /home/execute_update.
/// </summary>
public partial class UpdaterViewModel : ObservableObject
{
    private readonly ApiService _api;

    [ObservableProperty] private bool _isLoading = true;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _hasUpdate;
    [ObservableProperty] private string _branch = string.Empty;
    [ObservableProperty] private string _currentCommitText = string.Empty;
    [ObservableProperty] private string _latestCommitText = string.Empty;

    public List<List<string>> CommitHistory { get; private set; } = [];

    public UpdaterViewModel(ApiService api) => _api = api;

    public async Task LoadAsync()
    {
        IsLoading = true;
        StatusMessage = string.Empty;
        try
        {
            var info = await _api.GetUpdateInfoAsync();
            HasUpdate = info.IsUpdate;
            Branch = info.Branch;
            CurrentCommitText = FormatCommit(info.CurrentCommit);
            LatestCommitText = FormatCommit(info.LatestCommit);
            CommitHistory = info.Commit;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Failed to load update info: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task ExecuteUpdateAsync()
    {
        StatusMessage = "Executing update…";
        try
        {
            var result = await _api.ExecuteUpdateAsync();
            StatusMessage = string.IsNullOrEmpty(result) ? "Update triggered." : result;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Update failed: {ex.Message}";
        }
    }

    private static string FormatCommit(List<string> commit)
    {
        if (commit == null || commit.Count < 4) return string.Empty;
        return $"{commit[0][..Math.Min(7, commit[0].Length)]}  {commit[1]}  {commit[2]}  {commit[3]}";
    }
}
