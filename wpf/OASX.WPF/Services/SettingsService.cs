using System.IO;
using System.Text.Json;
using OASX.WPF.Models;

namespace OASX.WPF.Services;

/// <summary>
/// Persists and retrieves application settings using a JSON file.
/// </summary>
public class SettingsService
{
    private static readonly string SettingsFilePath =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OASX", "settings.json");

    private AppSettings _settings = new();

    public AppSettings Settings => _settings;

    public SettingsService()
    {
        Load();
    }

    public void Load()
    {
        try
        {
            if (File.Exists(SettingsFilePath))
            {
                var json = File.ReadAllText(SettingsFilePath);
                _settings = JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            }
        }
        catch
        {
            _settings = new AppSettings();
        }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsFilePath)!);
            var json = JsonSerializer.Serialize(_settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsFilePath, json);
        }
        catch
        {
            // ignore save errors
        }
    }

    public void UpdateCredentials(string address, string username, string password)
    {
        _settings.Address = address;
        _settings.Username = username;
        _settings.Password = password;
        Save();
    }

    public void UpdateTheme(string theme)
    {
        _settings.Theme = theme;
        Save();
    }

    public void UpdateLanguage(string language)
    {
        _settings.Language = language;
        Save();
    }
}
