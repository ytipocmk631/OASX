namespace OASX.WPF.Models;

/// <summary>
/// Application settings stored locally
/// </summary>
public class AppSettings
{
    public string Address { get; set; } = "127.0.0.1:22288";
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Theme { get; set; } = "Light";
    public string Language { get; set; } = "zh-CN";
}
