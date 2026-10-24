# Troubleshooting

## Pulse offline

- Start PulseService from **Diagnostics → Service**
- Confirm `\\.\pipe\PulseService` is not blocked by third-party security tools

## AI clients show a "pulse" server that fails to start

AI Integration (PulseMCP) was removed in 1.3. Pulse removes the entries it
added to Claude Desktop, Cursor, VS Code, Windsurf and Cline configs the first
time 1.3 starts, backing up each file as `*.pulse-backup-*`. If an entry you
added yourself remains, delete the `pulse` server from that client's MCP
settings.
