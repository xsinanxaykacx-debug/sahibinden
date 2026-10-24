# Sahibinden gerçek fotoğraf yükleme yardımcısı
# Yalnızca OEM + yönü kaynakta doğrulanan görseller bulunur.
# Çalıştırma: PowerShell'de repo kökünde: .\scripts\yukle_fotograflar.ps1

$ErrorActionPreference = 'Stop'
$Repo = 'xsinanxaykacx-debug/sahibinden'
$Root = (Get-Location).Path

$Items = @(
    @{
        Oem = '260100506R'
        Yon = 'sag'
        Sira = 1
        Url = 'https://www.cetinrenault.com/idea/ha/71/myassets/products/142/260100506r-renault-megane-4-on-sag-far-lambasi-ledli-siyah.jpg?revision=1739268315'
        Source = 'Çetin Renault; OEM 260100506R, Megane IV sağ ön far'
    },
    @{
        Oem = '260601571R'
        Yon = 'sol'
        Sira = 1
        Url = 'https://d1urxgbt2uly9x.cloudfront.net/parca-gorsel/1/987918904.jpg'
        Source = 'Otiva/TYC; OEM 260601571R, Megane IV sol ön far'
    }
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'gh CLI bulunamadı. GitHub CLI kurup gh auth login çalıştır.'
}
gh auth status | Out-Null

$Report = [System.Collections.Generic.List[string]]::new()
foreach ($Item in $Items) {
    $Name = '{0}_{1}_{2}.jpg' -f $Item.Oem, $Item.Yon, $Item.Sira
    $Dir = Join-Path $Root ('fotograflar\' + $Item.Oem)
    $Path = Join-Path $Dir $Name
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null

    try {
        curl.exe -L --fail --silent --show-error $Item.Url -o $Path
        if (-not (Test-Path $Path) -or (Get-Item $Path).Length -le 0) {
            throw 'İndirilen dosya boş.'
        }
        $Bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($Bytes.Length -lt 4 -or $Bytes[0] -ne 0xFF -or $Bytes[1] -ne 0xD8 -or $Bytes[2] -ne 0xFF) {
            Remove-Item $Path -Force
            throw 'Yanıt JPEG değil; dosya silindi.'
        }

        $B64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
        $RepoPath = 'fotograflar/{0}/{1}' -f $Item.Oem, $Name
        $Payload = @{
            message = "add $($Item.Oem) photo"
            content = $B64
        } | ConvertTo-Json -Compress
        $PayloadPath = Join-Path $env:TEMP ('gh_upload_' + [guid]::NewGuid().ToString('N') + '.json')
        [System.IO.File]::WriteAllText($PayloadPath, $Payload, [System.Text.UTF8Encoding]::new($false))
        try {
            gh api "repos/$Repo/contents/$RepoPath" -X PUT --input $PayloadPath | Out-Null
            $Check = gh api "repos/$Repo/contents/fotograflar/$($Item.Oem)/$Name" | ConvertFrom-Json
            if ([int]$Check.size -le 0) { throw 'GitHub doğrulaması başarısız: size 0.' }
            $Report.Add("$($Item.Oem) | 1 | EVET | $Name; $($Check.size) bayt; $($Item.Source)")
        }
        finally {
            Remove-Item $PayloadPath -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $Report.Add("$($Item.Oem) | 0 | HAYIR | $($_.Exception.Message)")
    }
}
$Report | Tee-Object -FilePath (Join-Path $Root 'fotograf_yukleme_raporu.txt')
