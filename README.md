# XDRHelper

## Synopsis

XDRHelper is designed to simplify interaction with the Defender for Endpoint API by providing
a PowerShell module wrapper around the Defender REST API.

## Description

<!-- Enter a description -->

## Why

<!-- Short reason you created the project -->

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
# command showing how to use your project
$AppId = '11111111-1111-1111-1111-111111111111'
$TenantId = '22222222-2222-2222-2222-222222222222'
$AppSecret = ConvertTo-SecureString 'FakeSecret' -AsPlainText -Force
Connect-XdrByAppId -AppId $AppId -AppSecret $AppSecret -TenantId $TenantId

Get-XdrDevice -All | Add-XdrTag -Tag 'xdrhelped'
```

## Author

John Bruckler

