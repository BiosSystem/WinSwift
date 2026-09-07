#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for the language catalogue loader and text resolution.
#>

Describe 'WinSwift localization' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
        . (Join-Path $repoRoot 'Scripts\FileIO\LoadJsonFile.ps1')
        . (Join-Path $repoRoot 'Scripts\FileIO\LoadLanguageFile.ps1')
        $script:realLanguagesPath = Join-Path $repoRoot 'Config\Languages'
    }

    BeforeEach {
        # A two-language fixture: es-ES translates only some keys, so fallback
        # to en-US can be observed per key rather than per language.
        $script:LanguagesPath = Join-Path $TestDrive 'Languages'
        foreach ($code in 'en-US', 'es-ES') {
            New-Item -ItemType Directory -Path (Join-Path $script:LanguagesPath $code) -Force | Out-Null
        }

        @{
            Version = '1'
            Features = @{
                DisableTelemetry = @{ Label = 'Disable telemetry'; ApplyText = 'Disabling telemetry'; ToolTip = 'English tip' }
                OnlyInEnglish = @{ Label = 'Only in English' }
            }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:LanguagesPath 'en-US\Features.json') -Encoding utf8

        @{ Version = '1'; Categories = @{ 'AI' = 'AI'; 'Gaming' = 'Gaming' } } |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:LanguagesPath 'en-US\Categories.json') -Encoding utf8

        @{
            Version = '1'
            Features = @{
                DisableTelemetry = @{ Label = 'Desactivar telemetria'; ApplyText = 'Desactivando telemetria' }
            }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:LanguagesPath 'es-ES\Features.json') -Encoding utf8

        @{ Version = '1'; Categories = @{ 'Gaming' = 'Juegos' } } |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $script:LanguagesPath 'es-ES\Categories.json') -Encoding utf8

        $script:Features = @{
            DisableTelemetry = [PSCustomObject]@{ FeatureId = 'DisableTelemetry'; Label = 'json label'; ApplyText = 'json apply' }
            NotInAnyCatalogue = [PSCustomObject]@{ FeatureId = 'NotInAnyCatalogue'; Label = 'json only'; ApplyText = 'json only apply' }
        }
        $script:Language = $null
    }

    Context 'folder resolution' {
        It 'prefers an exact match' {
            Resolve-LanguageFolder -LanguageCode 'es-ES' | Should -Be 'es-ES'
        }

        It 'falls back to another region sharing the language' {
            Resolve-LanguageFolder -LanguageCode 'es-MX' | Should -Be 'es-ES'
        }

        It 'falls back to en-US for an unknown language' {
            Resolve-LanguageFolder -LanguageCode 'ja-JP' | Should -Be 'en-US'
        }
    }

    Context 'catalogue loading' {
        It 'loads the requested language and attaches the en-US fallback' {
            $content = Import-LanguageFile -LanguageCode 'es-ES'

            $content.LanguageCode | Should -Be 'es-ES'
            $content.Fallback | Should -Not -BeNullOrEmpty
            $content.Fallback.LanguageCode | Should -Be 'en-US'
        }

        It 'does not attach a fallback to en-US itself' {
            (Import-LanguageFile -LanguageCode 'en-US').Fallback | Should -BeNullOrEmpty
        }

        It 'returns null rather than throwing when no catalogue exists' {
            $script:LanguagesPath = Join-Path $TestDrive 'Missing'
            Import-LanguageFile -LanguageCode 'en-US' -WarningAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    Context 'text resolution' {
        It 'returns the translated string when one exists' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            Get-WinSwiftFeatureText -FeatureId 'DisableTelemetry' -Key 'Label' | Should -Be 'Desactivar telemetria'
        }

        It 'falls back to en-US for a key the language does not translate' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            Get-WinSwiftFeatureText -FeatureId 'DisableTelemetry' -Key 'ToolTip' | Should -Be 'English tip'
        }

        It 'falls back to Features.json for a feature in no catalogue' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            Get-WinSwiftFeatureText -FeatureId 'NotInAnyCatalogue' -Key 'Label' | Should -Be 'json only'
        }

        It 'resolves from Features.json when no catalogue loaded at all' {
            $script:Language = $null

            Get-WinSwiftFeatureText -FeatureId 'DisableTelemetry' -Key 'Label' | Should -Be 'json label'
        }

        It 'returns the English category name when untranslated' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            Get-WinSwiftCategoryText -Category 'Gaming' | Should -Be 'Juegos'
            Get-WinSwiftCategoryText -Category 'AI' | Should -Be 'AI'
            Get-WinSwiftCategoryText -Category 'Unknown Category' | Should -Be 'Unknown Category'
        }
    }

    Context 'overlay onto loaded features' {
        It 'replaces feature text in place and reports the count' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            $replaced = Update-FeatureTextFromLanguage

            $replaced | Should -Be 2
            $script:Features['DisableTelemetry'].Label | Should -Be 'Desactivar telemetria'
            $script:Features['DisableTelemetry'].ApplyText | Should -Be 'Desactivando telemetria'
        }

        It 'leaves features with no translation untouched' {
            $script:Language = Import-LanguageFile -LanguageCode 'es-ES'

            $null = Update-FeatureTextFromLanguage

            $script:Features['NotInAnyCatalogue'].Label | Should -Be 'json only'
        }

        It 'changes nothing when no catalogue is loaded' {
            $script:Language = $null

            Update-FeatureTextFromLanguage | Should -Be 0
            $script:Features['DisableTelemetry'].Label | Should -Be 'json label'
        }
    }

    Context 'XAML chrome substitution' {

        BeforeEach {
            $script:Language = [PSCustomObject]@{
                LanguageCode = 'xx-XX'
                Chrome = [PSCustomObject]@{
                    'Apply changes' = 'Aplicar cambios'
                    'Risky & <bad>' = 'Peligro & <malo>'
                }
                Features = $null
                Categories = $null
                Fallback = $null
            }
            $script:sample = Join-Path $TestDrive 'sample.xaml'
        }

        It 'substitutes a translated attribute' {
            '<Window><Button Content="Apply changes" /></Window>' |
                Set-Content -LiteralPath $script:sample -Encoding utf8

            Get-LocalizedXaml -Path $script:sample | Should -Match 'Content="Aplicar cambios"'
        }

        It 'leaves untranslated text alone' {
            '<Window><Button Content="Not in catalogue" /></Window>' |
                Set-Content -LiteralPath $script:sample -Encoding utf8

            Get-LocalizedXaml -Path $script:sample | Should -Match 'Content="Not in catalogue"'
        }

        It 'does not touch bindings' {
            '<Window><Button Content="{Binding Apply}" /></Window>' |
                Set-Content -LiteralPath $script:sample -Encoding utf8

            Get-LocalizedXaml -Path $script:sample | Should -BeLike '*{Binding Apply}*'
        }

        It 'XML-encodes a translation containing markup characters' {
            '<Window><Button Content="Risky &amp; &lt;bad&gt;" /></Window>' |
                Set-Content -LiteralPath $script:sample -Encoding utf8

            $result = Get-LocalizedXaml -Path $script:sample
            $result | Should -BeLike '*Peligro &amp; &lt;malo&gt;*'
            $result | Should -Not -BeLike '*Peligro & <malo>*'
        }

        It 'returns the markup unchanged when no catalogue is loaded' {
            $script:Language = $null
            '<Window><Button Content="Apply changes" /></Window>' |
                Set-Content -LiteralPath $script:sample -Encoding utf8

            Get-LocalizedXaml -Path $script:sample | Should -BeLike '*Content="Apply changes"*'
        }
    }

    Context 'the shipped en-US catalogue' {
        It 'covers every feature in Features.json' {
            $catalogue = LoadJsonFile -filePath (Join-Path $script:realLanguagesPath 'en-US\Features.json')
            $features = (Get-Content (Join-Path (Split-Path $script:realLanguagesPath -Parent) 'Features.json') -Raw | ConvertFrom-Json).Features

            $missing = @($features | Where-Object {
                -not $catalogue.Features.PSObject.Properties[$_.FeatureId]
            } | ForEach-Object { $_.FeatureId })

            $missing | Should -BeNullOrEmpty -Because "features absent from the en-US catalogue: $($missing -join ', ')"
        }

        It 'matches the English text in Features.json exactly' {
            $catalogue = LoadJsonFile -filePath (Join-Path $script:realLanguagesPath 'en-US\Features.json')
            $features = (Get-Content (Join-Path (Split-Path $script:realLanguagesPath -Parent) 'Features.json') -Raw | ConvertFrom-Json).Features

            $drift = [System.Collections.Generic.List[string]]::new()
            foreach ($feature in $features) {
                $entry = $catalogue.Features.PSObject.Properties[$feature.FeatureId]
                if (-not $entry) { continue }

                foreach ($key in 'Label', 'ToolTip', 'ApplyText', 'UndoLabel', 'ApplyUndoText') {
                    $source = [string]$feature.$key
                    if ([string]::IsNullOrWhiteSpace($source)) { continue }

                    $translated = $entry.Value.PSObject.Properties[$key]
                    if (-not $translated -or [string]$translated.Value -ne $source) {
                        $drift.Add("$($feature.FeatureId).$key")
                    }
                }
            }

            $drift | Should -BeNullOrEmpty -Because "en-US catalogue has drifted from Features.json: $($drift -join ', ')"
        }

        It 'covers every category' {
            $catalogue = LoadJsonFile -filePath (Join-Path $script:realLanguagesPath 'en-US\Categories.json')
            $features = (Get-Content (Join-Path (Split-Path $script:realLanguagesPath -Parent) 'Features.json') -Raw | ConvertFrom-Json).Features

            $categories = @($features | ForEach-Object { $_.Category } | Where-Object { $_ } | Select-Object -Unique)
            $missing = @($categories | Where-Object { -not $catalogue.Categories.PSObject.Properties[$_] })

            $missing | Should -BeNullOrEmpty -Because "categories absent from the en-US catalogue: $($missing -join ', ')"
        }

        It 'covers every translatable string in the schemas' {
            # Guards against a new XAML string being added without a catalogue
            # entry. Glyph character references and bindings are not text.
            $catalogue = LoadJsonFile -filePath (Join-Path $script:realLanguagesPath 'en-US\Chrome.json')
            $schemasPath = Join-Path (Split-Path (Split-Path $script:realLanguagesPath -Parent) -Parent) 'Schemas'

            $missing = [System.Collections.Generic.List[string]]::new()
            foreach ($schema in Get-ChildItem $schemasPath -Filter *.xaml) {
                $markup = Get-Content -LiteralPath $schema.FullName -Raw
                foreach ($match in [regex]::Matches($markup, '(?:Content|Text|Header|ToolTip|Title)="([^"]*)"')) {
                    $raw = $match.Groups[1].Value
                    if ($raw.Length -lt 2) { continue }
                    if ($raw -match '^\s*\{') { continue }
                    if ($raw -match '^(&#x?[0-9A-Fa-f]+;\s*)+$') { continue }

                    $decoded = [System.Net.WebUtility]::HtmlDecode($raw)
                    if ($decoded -match '^[\W\d_]+$') { continue }

                    if (-not $catalogue.Chrome.PSObject.Properties[$decoded]) {
                        $missing.Add("$($schema.Name): $decoded")
                    }
                }
            }

            $missing | Should -BeNullOrEmpty -Because "schema strings absent from Chrome.json: $($missing -join '; ')"
        }
    }
}
