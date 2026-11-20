# XDRHelper

[![XDRHelper-Windows-pwsh](https://github.com/jpbruckler/XDRHelper/actions/workflows/wf_Windows_Core.yml/badge.svg)](https://github.com/jpbruckler/XDRHelper/actions/workflows/wf_Windows_Core.yml)

## Synopsis

XDRHelper is exists to simplify interaction with the Defender for Endpoint API
by providing a PowerShell module wrapper around the Defender REST API.

## Description

Manages the OAuth authentication to the Defender for Endpoint API and provides
cmdlets for interacting with the API endpoints. This module started as a helper
to prevent writing authentication, reauthentication, and API response paging in
yet another script.

This module is primarily intended to assist with automation tasks using the
documented API endpoints.

Planned features:

Currently the plan is to try to implement as much of the [supported API](https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-list) as
possible.

Completed features:

- [X] Authenticate to the API and manage re-authentication when a token expires
- [X] Retrieve device information by Id or OData filter
- [X] Add or remove device tags for one or multiple devices
- [X] Set device value and overwrite tags for one or multiple devices

## Getting Started

### Prerequisites

- Requires PowerShell version 7.4 or greater

### Installation

```powershell
# how to install XDRHelper
Install-Module XDRHelper
```

### Quick start

#### Example1

```powershell
# requires an Entra app registration, app id, and app secret to connect
$AppId = '11111111-1111-1111-1111-111111111111'
$TenantId = '22222222-2222-2222-2222-222222222222'
$AppSecret = ConvertTo-SecureString 'FakeSecret' -AsPlainText -Force
Connect-XdrByAppId -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

# add the tag 'xdrhelpwed' all all devices in the Defender tenant
Get-XdrDevice -All | Add-XdrTag -Tag 'xdrhelped'
```

## Author

John Bruckler