# Oratório — servidor local simples (só para este computador)
# Abre o app em http://localhost para que as vozes do Oratório funcionem.
# Feche esta janela para encerrar.

$ErrorActionPreference = 'Continue'
$raiz = (Resolve-Path (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$tipos = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'; '.webmanifest' = 'application/manifest+json'
  '.wasm' = 'application/wasm'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'
  '.css' = 'text/css'; '.txt' = 'text/plain; charset=utf-8'
  '.onnx' = 'application/octet-stream'; '.data' = 'application/octet-stream'
}

# Procura uma porta livre entre 8080 e 8090
$ouvinte = $null
foreach ($porta in 8080..8090) {
  $tentativa = New-Object System.Net.HttpListener
  $tentativa.Prefixes.Add("http://localhost:$porta/")
  try { $tentativa.Start(); $ouvinte = $tentativa; break } catch { $tentativa.Close() }
}
if (-not $ouvinte) {
  Write-Host 'Não foi possível abrir o Oratório (portas 8080 a 8090 ocupadas).'
  Read-Host 'Tecle Enter para sair'
  exit 1
}

$endereco = "http://localhost:$porta/index.html"
Write-Host ''
Write-Host '  ORATÓRIO aberto no navegador.'
Write-Host "  Endereço: $endereco"
Write-Host '  Deixe esta janela aberta enquanto usar o app. Para encerrar, feche-a.'
Write-Host ''
Start-Process $endereco

while ($ouvinte.IsListening) {
  try { $ctx = $ouvinte.GetContext() } catch { break }
  $resp = $ctx.Response
  try {
    $caminho = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ([string]::IsNullOrEmpty($caminho)) { $caminho = 'index.html' }
    $arquivo = [IO.Path]::GetFullPath((Join-Path $raiz $caminho))
    if ($arquivo.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
      $ext = [IO.Path]::GetExtension($arquivo).ToLower()
      if ($tipos.ContainsKey($ext)) { $resp.ContentType = $tipos[$ext] } else { $resp.ContentType = 'application/octet-stream' }
      $resp.Headers.Add('Cache-Control', 'no-cache')
      $fluxo = [IO.File]::OpenRead($arquivo)
      try { $resp.ContentLength64 = $fluxo.Length; $fluxo.CopyTo($resp.OutputStream) } finally { $fluxo.Close() }
    } else {
      $resp.StatusCode = 404
    }
  } catch {
    # o navegador pode cancelar um pedido no meio; segue normalmente
  } finally {
    try { $resp.OutputStream.Close() } catch {}
  }
}
