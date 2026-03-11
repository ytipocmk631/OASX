namespace OASX.WPF.Models;

/// <summary>
/// A single argument within a task group.
/// </summary>
public class ArgModel
{
    public string Name { get; init; } = string.Empty;
    public string TranslatedName { get; set; } = string.Empty;
    public string Type { get; init; } = "string";
    public string? Description { get; init; }
    public string? TranslatedDescription { get; set; }
    public List<string> EnumOptions { get; init; } = [];
    public object? Value { get; set; }

    /// <summary>Called by ArgsViewModel when the user changes this arg's value.</summary>
    internal Func<object?, Task>? SaveCallback { get; set; }
}

/// <summary>
/// A named group of arguments (one accordion section in the Args view).
/// </summary>
public class ArgGroupModel
{
    public string GroupName { get; init; } = string.Empty;
    public string TranslatedGroupName { get; set; } = string.Empty;
    public List<ArgModel> Members { get; init; } = [];
}

/// <summary>
/// An item in the task-selection list (left-side second panel).
/// IsHeader items are section titles and are not selectable.
/// </summary>
public class MenuItemModel
{
    public string Name { get; init; } = string.Empty;
    public bool IsHeader { get; init; }

    /// <summary>Translated display name using the current LocalizationService language.</summary>
    public string DisplayName => Services.LocalizationService.Instance.Translate(Name);
}
