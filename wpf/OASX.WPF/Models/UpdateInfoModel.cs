namespace OASX.WPF.Models;

/// <summary>
/// Mirrors the server's update_info JSON response from /home/update_info.
/// Each commit is a 4-element list: [sha1, author, datetime, message].
/// </summary>
public class UpdateInfoModel
{
    public bool IsUpdate { get; set; }
    public string Branch { get; set; } = string.Empty;
    public List<string> CurrentCommit { get; set; } = [];
    public List<string> LatestCommit { get; set; } = [];
    public List<List<string>> Commit { get; set; } = [];
}
