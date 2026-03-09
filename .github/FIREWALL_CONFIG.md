# GitHub Copilot Agent Firewall Configuration

This document explains how the GitHub Copilot agent firewall is configured for this repository.

## Overview

GitHub Copilot's coding agent includes a firewall to restrict network access and prevent data exfiltration. By default, it only allows access to trusted hosts like package registries and certificate authorities.

## Current Configuration

The firewall allowlist is configured in `.github/copilot-firewall.yaml` and includes:

- **`open.bigmodel.cn`** - Zhipu AI (智谱AI) API endpoint for GLM (General Language Model) access

## Configuration Methods

There are two ways to configure the firewall allowlist:

### 1. File-Based Configuration (Current Method)

Create or edit `.github/copilot-firewall.yaml` in your repository:

```yaml
allowlist:
  - "open.bigmodel.cn"
  - "example.com"
```

**Advantages:**
- Version controlled
- Easy to review in pull requests
- Transparent to all contributors

### 2. Repository Settings (Alternative)

Configure via GitHub's web interface:

1. Go to **Settings** → **Copilot** → **Coding agent**
2. Add domains to the allowlist in the Firewall section

**Advantages:**
- No code changes needed
- Can be managed by repository administrators
- Immediate effect without commits

## Adding Additional Domains

If the Copilot agent needs access to additional domains:

1. **Via File:** Add the domain to `.github/copilot-firewall.yaml`
2. **Via Settings:** Use repository variable `COPILOT_AGENT_FIREWALL_ALLOW_LIST_ADDITIONS` (comma-separated list)

## Blocklist

You can also explicitly block domains using a `blocklist` section:

```yaml
allowlist:
  - "trusted.example.com"
blocklist:
  - "untrusted.example.com"
```

## Security Considerations

- Only add domains that are necessary and trusted
- Review allowlist changes carefully in pull requests
- The firewall only protects against agent-initiated network requests
- Setup steps in GitHub Actions run before the firewall is enabled

## References

- [GitHub Copilot Agent Firewall Documentation](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-firewall)
- [Copilot Allowlist Reference](https://docs.github.com/en/copilot/reference/copilot-allowlist-reference)
- [Troubleshooting Firewall Settings](https://docs.github.com/en/copilot/how-tos/troubleshoot-copilot/troubleshoot-firewall-settings)

## Troubleshooting

If you encounter firewall blocks:

1. Check the error message for the blocked domain
2. Add the domain to `.github/copilot-firewall.yaml`
3. If you need immediate access, use repository settings
4. For setup steps, configure them before the firewall is enabled using [Actions setup steps](https://gh.io/copilot/actions-setup-steps)
