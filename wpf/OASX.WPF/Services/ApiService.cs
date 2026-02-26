using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Nodes;
using OASX.WPF.Models;

namespace OASX.WPF.Services;

/// <summary>
/// HTTP API client for communicating with the OAS backend server.
/// Base URL: http://{address}
/// </summary>
public class ApiService
{
    private readonly HttpClient _http;
    private string _baseUrl = "http://127.0.0.1:22288";

    public ApiService(HttpClient httpClient)
    {
        _http = httpClient;
        _http.Timeout = TimeSpan.FromSeconds(10);
    }

    public void SetAddress(string address)
    {
        _baseUrl = address.StartsWith("http://") ? address : $"http://{address}";
        _http.BaseAddress = new Uri(_baseUrl);
    }

    public string CurrentAddress => _baseUrl;

    // ---------- Connection test ----------

    public async Task<bool> TestAddressAsync()
    {
        try
        {
            var result = await GetStringAsync("/test");
            return result?.Trim('"') == "success";
        }
        catch { return false; }
    }

    public async Task<bool> KillServerAsync()
    {
        try
        {
            var result = await GetStringAsync("/home/kill_server");
            return result?.Trim('"') == "success";
        }
        catch { return false; }
    }

    // ---------- Config management ----------

    public async Task<List<string>> GetConfigListAsync()
    {
        try
        {
            var json = await GetStringAsync("/config_list");
            var list = JsonSerializer.Deserialize<List<string>>(json ?? "[]") ?? [];
            return ["Home", .. list];
        }
        catch { return ["Home"]; }
    }

    public async Task<List<string>> GetConfigAllAsync()
    {
        try
        {
            var json = await GetStringAsync("/config_all");
            return JsonSerializer.Deserialize<List<string>>(json ?? "[]") ?? ["template"];
        }
        catch { return ["template"]; }
    }

    public async Task<string> GetNewConfigNameAsync()
    {
        try
        {
            var result = await GetStringAsync("/config_new_name");
            return result?.Trim('"') ?? string.Empty;
        }
        catch { return string.Empty; }
    }

    public async Task<List<string>> ConfigCopyAsync(string newName, string template)
    {
        try
        {
            var url = $"{_baseUrl}/config_copy?file={Uri.EscapeDataString(newName)}&template={Uri.EscapeDataString(template)}";
            var response = await _http.PostAsync(url, null);
            var json = await response.Content.ReadAsStringAsync();
            var list = JsonSerializer.Deserialize<List<string>>(json) ?? [];
            return ["Home", .. list];
        }
        catch { return ["Home"]; }
    }

    public async Task<bool> DeleteConfigAsync(string name)
    {
        try
        {
            var request = new HttpRequestMessage(HttpMethod.Delete, $"{_baseUrl}/config?name={Uri.EscapeDataString(name)}");
            var response = await _http.SendAsync(request);
            var json = await response.Content.ReadAsStringAsync();
            return json.Trim() == "true";
        }
        catch { return false; }
    }

    public async Task<bool> RenameConfigAsync(string oldName, string newName)
    {
        try
        {
            var request = new HttpRequestMessage(HttpMethod.Put,
                $"{_baseUrl}/config?old_name={Uri.EscapeDataString(oldName)}&new_name={Uri.EscapeDataString(newName)}");
            var response = await _http.SendAsync(request);
            var json = await response.Content.ReadAsStringAsync();
            return json.Trim() == "true";
        }
        catch { return false; }
    }

    // ---------- Script menus ----------

    public async Task<Dictionary<string, List<string>>> GetScriptMenuAsync()
    {
        try
        {
            var json = await GetStringAsync("/script_menu");
            return ParseMenuDict(json);
        }
        catch { return []; }
    }

    public async Task<Dictionary<string, List<string>>> GetHomeMenuAsync()
    {
        try
        {
            var json = await GetStringAsync("/home/home_menu");
            return ParseMenuDict(json);
        }
        catch { return []; }
    }

    // ---------- Translations ----------

    /// <summary>
    /// Pushes the Chinese translation dictionary to the OAS backend so it can use
    /// those translations when serving arg names and descriptions (mirrors Flutter's putChineseTranslate).
    /// </summary>
    public async Task<bool> PutChineseTranslateAsync(Dictionary<string, string> translations)
    {
        try
        {
            var json = JsonSerializer.Serialize(translations);
            var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            var response = await _http.PutAsync($"{_baseUrl}/home/chinese_translate", content);
            var result = await response.Content.ReadAsStringAsync();
            return result.Trim() == "true";
        }
        catch { return false; }
    }

    /// <summary>
    /// Fetches server-specific additional translations (mirrors Flutter's getAdditionalTranslate).
    /// Returns a map of locale → (key → translated text).
    /// </summary>
    public async Task<Dictionary<string, Dictionary<string, string>>> GetAdditionalTranslateAsync()
    {
        try
        {
            var json = await GetStringAsync("/home/additional_translate");
            if (string.IsNullOrWhiteSpace(json)) return [];
            var node = JsonNode.Parse(json) as JsonObject;
            if (node == null) return [];
            var result = new Dictionary<string, Dictionary<string, string>>();
            foreach (var kvp in node)
            {
                if (kvp.Value is JsonObject localeObj)
                {
                    var dict = new Dictionary<string, string>();
                    foreach (var entry in localeObj)
                        dict[entry.Key] = entry.Value?.ToString() ?? string.Empty;
                    result[kvp.Key] = dict;
                }
            }
            return result;
        }
        catch { return []; }
    }


    public async Task<JsonObject?> GetScriptTaskArgsAsync(string scriptName, string taskName)
    {
        try
        {
            var json = await GetStringAsync($"/{scriptName}/{taskName}/args");
            return JsonNode.Parse(json ?? "{}") as JsonObject;
        }
        catch { return null; }
    }

    public async Task<bool> PutScriptArgAsync(string scriptName, string taskName,
        string groupName, string argName, string type, object value)
    {
        try
        {
            // Python backend expects lowercase "true"/"false" for booleans
            var valueStr = value is bool boolVal
                ? boolVal.ToString().ToLowerInvariant()
                : value?.ToString() ?? string.Empty;
            var url = $"{_baseUrl}/{scriptName}/{taskName}/{groupName}/{argName}/value?types={Uri.EscapeDataString(type)}&value={Uri.EscapeDataString(valueStr)}";
            var request = new HttpRequestMessage(HttpMethod.Put, url);
            var response = await _http.SendAsync(request);
            var json = await response.Content.ReadAsStringAsync();
            return json.Trim() == "true";
        }
        catch { return false; }
    }

    // ---------- Home views ----------

    public async Task<UpdateInfoModel> GetUpdateInfoAsync()
    {
        try
        {
            var json = await GetStringAsync("/home/update_info");
            if (string.IsNullOrWhiteSpace(json)) return new();
            var node = JsonNode.Parse(json) as JsonObject;
            if (node == null) return new();
            return new UpdateInfoModel
            {
                IsUpdate = node["is_update"]?.GetValue<bool>() ?? false,
                Branch = node["branch"]?.ToString() ?? string.Empty,
                CurrentCommit = ParseStringList(node["current_commit"]),
                LatestCommit = ParseStringList(node["latest_commit"]),
                Commit = ParseStringListList(node["commit"]),
            };
        }
        catch { return new(); }
    }

    public async Task<string> ExecuteUpdateAsync()
    {
        try { return (await GetStringAsync("/home/execute_update"))?.Trim('"') ?? string.Empty; }
        catch { return string.Empty; }
    }

    public async Task<bool> NotifyTestAsync(string setting, string title, string content)
    {
        try
        {
            var url = $"{_baseUrl}/home/notify_test?setting={Uri.EscapeDataString(setting)}&title={Uri.EscapeDataString(title)}&content={Uri.EscapeDataString(content)}";
            var response = await _http.PostAsync(url, null);
            var json = await response.Content.ReadAsStringAsync();
            return json.Trim() == "true";
        }
        catch { return false; }
    }

    private static List<string> ParseStringList(JsonNode? node)
    {
        if (node is not JsonArray arr) return [];
        return arr.Select(v => v?.ToString() ?? string.Empty).ToList();
    }

    private static List<List<string>> ParseStringListList(JsonNode? node)
    {
        if (node is not JsonArray outer) return [];
        return outer
            .OfType<JsonArray>()
            .Select(inner => inner.Select(v => v?.ToString() ?? string.Empty).ToList())
            .ToList();
    }

    private async Task<string?> GetStringAsync(string path)
    {
        var url = path.StartsWith("http") ? path : $"{_baseUrl}{path}";
        var response = await _http.GetAsync(url);
        return await response.Content.ReadAsStringAsync();
    }

    private static Dictionary<string, List<string>> ParseMenuDict(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];
        var node = JsonNode.Parse(json) as JsonObject;
        if (node == null) return [];
        var result = new Dictionary<string, List<string>>();
        foreach (var kvp in node)
        {
            var values = kvp.Value?.AsArray().Select(v => v?.ToString() ?? "").ToList() ?? [];
            result[kvp.Key] = values;
        }
        return result;
    }
}
