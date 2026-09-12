# Security policy

## Supported versions

The latest released `0.1.x` version receives security fixes during the beta.

## Reporting a vulnerability

Do not open a public issue. Use GitHub's **Security → Report a vulnerability** flow in this
repository. Include reproduction steps, impact, and affected versions, but never include a live
ViaPost API key. We will acknowledge the report within three business days.

## Credentials

Load API keys from environment variables or a secrets manager. Never commit, log, or send them in
issue reports. Rotate a key immediately if it may have been disclosed.

