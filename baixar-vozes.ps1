# Oratório — baixa as vozes de leitura para a pasta "voz"
# São 5 vozes (cerca de 63 MB cada). Vozes já baixadas são puladas.

$raiz = (Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$pasta = Join-Path $raiz 'voz'
$rhasspy = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR'
$ovos = 'https://huggingface.co/OpenVoiceOS'
$vozes = @(
  @{ Nome = 'Faber (masculina)'; Base = "$rhasspy/faber/medium/pt_BR-faber-medium" },
  @{ Nome = 'Cadu (masculina)';  Base = "$rhasspy/cadu/medium/pt_BR-cadu-medium" },
  @{ Nome = 'Jeff (masculina)';  Base = "$rhasspy/jeff/medium/pt_BR-jeff-medium" },
  @{ Nome = 'Miro (masculina)';  Base = "$ovos/pipertts_pt-BR_miro/resolve/main/miro_pt-BR" },
  @{ Nome = 'Dii (feminina)';    Base = "$ovos/pipertts_pt-BR_dii/resolve/main/dii_pt-BR" }
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$temCurl = [bool](Get-Command curl.exe -ErrorAction SilentlyContinue)
$falhas = 0

Write-Host ''
Write-Host '  ORATÓRIO — baixando as vozes de leitura'
Write-Host '  Use o Wi-Fi. Pode levar alguns minutos.'
Write-Host ''

foreach ($v in $vozes) {
  Write-Host "  Voz $($v.Nome)"
  foreach ($ext in @('.onnx.json', '.onnx')) {
    $nome = (Split-Path $v.Base -Leaf) + $ext
    $destino = Join-Path $pasta $nome
    if ((Test-Path -LiteralPath $destino) -and ((Get-Item -LiteralPath $destino).Length -gt 0)) {
      Write-Host "    $nome já existe — pulando"
      continue
    }
    $parcial = "$destino.parcial"
    try {
      if ($temCurl) {
        & curl.exe -L --fail --retry 3 --progress-bar -o $parcial ($v.Base + $ext)
        if ($LASTEXITCODE -ne 0) { throw "curl $LASTEXITCODE" }
      } else {
        Invoke-WebRequest -Uri ($v.Base + $ext) -OutFile $parcial -UseBasicParsing
      }
      Move-Item -LiteralPath $parcial -Destination $destino -Force
      Write-Host "    $nome — ok"
    } catch {
      $falhas++
      if (Test-Path -LiteralPath $parcial) { Remove-Item -LiteralPath $parcial -Force }
      Write-Host "    $nome — NÃO foi possível baixar ($_)"
    }
  }
}

Write-Host ''
if ($falhas -eq 0) { Write-Host '  Pronto! Todas as vozes estão na pasta "voz".' }
else { Write-Host "  Terminou com $falhas falha(s). Verifique a internet e rode de novo: os arquivos já baixados serão pulados." }
Write-Host '  Agora abra o app pelo atalho "Abrir Oratorio" e escolha a voz no botão VOZ.'
Write-Host ''
Read-Host '  Tecle Enter para fechar'
