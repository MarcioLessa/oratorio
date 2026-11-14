/* =====================================================================
   Oratório — Voz neural (Piper TTS) rodando num Web Worker
   - Fonemas: espeak-ng compilado para WebAssembly (piper_phonemize.*)
   - Síntese: modelo ONNX "pt_BR-faber-medium" (voz masculina brasileira)
     executado com o ONNX Runtime Web (ort.wasm.min.js + ort-wasm-simd.wasm)
   Tudo roda no próprio aparelho; nada é enviado para a internet.
   ===================================================================== */
'use strict';
importScripts('ort.wasm.min.js', 'piper_phonemize.js');

ort.env.wasm.numThreads = 1;      // não exige isolamento de origem
ort.env.wasm.simd = true;
ort.env.wasm.wasmPaths = './';

let sessao = null;       // ort.InferenceSession
let config = null;       // conteúdo do .onnx.json
let wasmFonemas = null;  // ArrayBuffer de piper_phonemize.wasm
let dadosFonemas = null; // ArrayBuffer de piper_phonemize.data (dicionários do espeak)

async function baixar(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error('Falha ao abrir ' + url);
  return r.arrayBuffer();
}

/** Converte texto em números de fonemas usando o espeak-ng (pt-br). */
function fonemas(texto) {
  return new Promise((resolver, rejeitar) => {
    let saida = null;
    createPiperPhonemize({
      wasmBinary: wasmFonemas,
      getPreloadedPackage: () => dadosFonemas,
      print: (linha) => { try { saida = JSON.parse(linha).phoneme_ids; } catch (e) { /* ignora */ } },
      printErr: () => {},
      locateFile: (u) => u
    }).then((m) => {
      try {
        m.callMain(['-l', config.espeak.voice, '--input', JSON.stringify([{ text: texto }]), '--espeak_data', '/espeak-ng-data']);
        if (saida) resolver(saida); else rejeitar(new Error('Sem fonemas'));
      } catch (e) { rejeitar(e); }
    }, rejeitar);
  });
}

/** Sintetiza uma frase e devolve o áudio (Float32, mono). */
async function sintetizar(texto, velocidade) {
  const ids = await fonemas(texto);
  const inf = config.inference || {};
  const entradas = {
    input: new ort.Tensor('int64', BigInt64Array.from(ids.map(BigInt)), [1, ids.length]),
    input_lengths: new ort.Tensor('int64', BigInt64Array.from([BigInt(ids.length)]), [1]),
    scales: new ort.Tensor('float32', Float32Array.from([
      inf.noise_scale ?? 0.667,
      (inf.length_scale ?? 1) * (velocidade || 1),
      inf.noise_w ?? 0.8
    ]), [3])
  };
  if (config.speaker_id_map && Object.keys(config.speaker_id_map).length) {
    entradas.sid = new ort.Tensor('int64', BigInt64Array.from([0n]), [1]);
  }
  const { output } = await sessao.run(entradas);
  return new Float32Array(output.data);
}

self.onmessage = async (e) => {
  const msg = e.data;
  try {
    if (msg.tipo === 'iniciar') {
      config = msg.config;
      [wasmFonemas, dadosFonemas] = await Promise.all([baixar('piper_phonemize.wasm'), baixar('piper_phonemize.data')]);
      sessao = await ort.InferenceSession.create(msg.modelo, { executionProviders: ['wasm'], graphOptimizationLevel: 'all' });
      self.postMessage({ tipo: 'pronta', taxa: config.audio.sample_rate });
    } else if (msg.tipo === 'falar') {
      const audio = await sintetizar(msg.texto, msg.velocidade);
      self.postMessage({ tipo: 'audio', id: msg.id, audio }, [audio.buffer]);
    }
  } catch (erro) {
    self.postMessage({ tipo: 'erro', id: msg.id, mensagem: String(erro && erro.message || erro) });
  }
};
