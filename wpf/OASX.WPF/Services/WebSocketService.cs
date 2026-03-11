using System.Net.WebSockets;
using System.Text;

namespace OASX.WPF.Services;

public enum WsStatus { Connecting, Connected, Reconnecting, Closed, Error }

public delegate void MessageListener(string message);

/// <summary>
/// Manages WebSocket connections to OAS script instances.
/// </summary>
public class WebSocketService : IDisposable
{
    private readonly Dictionary<string, WebSocketClient> _clients = [];

    public async Task<WebSocketClient> ConnectAsync(
        string name,
        string baseAddress,
        MessageListener? listener = null,
        bool force = false)
    {
        if (!force && _clients.TryGetValue(name, out var existing))
        {
            existing.AddListener(listener);
            return existing;
        }

        if (force && _clients.ContainsKey(name))
            await CloseAsync(name, reconnect: false);

        var wsUrl = $"ws://{baseAddress.Replace("http://", "").Replace("https://", "")}/ws/{name}";
        var client = new WebSocketClient(name, wsUrl);
        client.AddListener(listener);
        _clients[name] = client;
        await client.ConnectAsync();
        return client;
    }

    public async Task CloseAsync(string name, bool reconnect = false)
    {
        if (_clients.TryGetValue(name, out var client))
        {
            await client.CloseAsync(reconnect);
            _clients.Remove(name);
        }
    }

    public async Task CloseAllAsync()
    {
        foreach (var client in _clients.Values)
            await client.CloseAsync(false);
        _clients.Clear();
    }

    public void Dispose() 
    {
        foreach (var client in _clients.Values)
            client.Dispose();
        _clients.Clear();
    }
}

/// <summary>
/// A single WebSocket connection to a named OAS script.
/// </summary>
public class WebSocketClient : IDisposable
{
    private const int MaxReconnect = 10;

    public string Name { get; }
    public string Url { get; }
    public WsStatus Status { get; private set; } = WsStatus.Connecting;

    private ClientWebSocket? _ws;
    private readonly List<MessageListener> _listeners = [];
    private bool _shouldReconnect = true;
    private int _reconnectCount = 0;
    private CancellationTokenSource _cts = new();

    public event Action<WsStatus>? StatusChanged;

    public WebSocketClient(string name, string url)
    {
        Name = name;
        Url = url;
    }

    public void AddListener(MessageListener? listener)
    {
        if (listener != null && !_listeners.Contains(listener))
            _listeners.Add(listener);
    }

    public void RemoveListener(MessageListener listener) => _listeners.Remove(listener);

    public async Task SendAsync(string message)
    {
        if (_ws?.State == WebSocketState.Open)
        {
            var bytes = Encoding.UTF8.GetBytes(message);
            await _ws.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None);
        }
    }

    public async Task ConnectAsync()
    {
        _cts = new CancellationTokenSource();
        SetStatus(WsStatus.Connecting);
        try
        {
            _ws = new ClientWebSocket();
            await _ws.ConnectAsync(new Uri(Url), _cts.Token);
            SetStatus(WsStatus.Connected);
            _reconnectCount = 0;
            _ = ReceiveLoopAsync();
        }
        catch
        {
            SetStatus(WsStatus.Error);
            Reconnect();
        }
    }

    public async Task CloseAsync(bool reconnect = false)
    {
        _shouldReconnect = reconnect;
        _cts.Cancel();
        if (_ws != null && (_ws.State == WebSocketState.Open || _ws.State == WebSocketState.CloseReceived))
        {
            try { await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "close", CancellationToken.None); }
            catch { /* ignore */ }
        }
        SetStatus(WsStatus.Closed);
        _listeners.Clear();
    }

    private async Task ReceiveLoopAsync()
    {
        var buffer = new byte[8192];
        var sb = new StringBuilder();
        try
        {
            while (_ws?.State == WebSocketState.Open && !_cts.IsCancellationRequested)
            {
                var result = await _ws.ReceiveAsync(buffer, _cts.Token);
                if (result.MessageType == WebSocketMessageType.Close)
                    break;

                sb.Append(Encoding.UTF8.GetString(buffer, 0, result.Count));
                if (result.EndOfMessage)
                {
                    var msg = sb.ToString();
                    sb.Clear();
                    foreach (var listener in _listeners.ToList())
                        listener(msg);
                }
            }
        }
        catch (OperationCanceledException) { }
        catch { SetStatus(WsStatus.Error); }

        if (_shouldReconnect)
            Reconnect();
        else
            SetStatus(WsStatus.Closed);
    }

    private void Reconnect()
    {
        if (!_shouldReconnect) { SetStatus(WsStatus.Closed); return; }
        if (++_reconnectCount > MaxReconnect) { SetStatus(WsStatus.Error); return; }

        SetStatus(WsStatus.Reconnecting);
        _ = Task.Run(async () =>
        {
            await Task.Delay(TimeSpan.FromSeconds(2));
            try { await ConnectAsync(); }
            catch { SetStatus(WsStatus.Error); }
        });
    }

    public void Dispose()
    {
        _cts.Cancel();
        if (_ws != null && (_ws.State == WebSocketState.Open || _ws.State == WebSocketState.CloseReceived))
        {
            try { _ws.CloseOutputAsync(WebSocketCloseStatus.NormalClosure, "dispose", CancellationToken.None).GetAwaiter().GetResult(); }
            catch { /* ignore */ }
        }
        _ws?.Dispose();
        _cts.Dispose();
    }

    private void SetStatus(WsStatus status)
    {
        Status = status;
        StatusChanged?.Invoke(status);
    }
}
