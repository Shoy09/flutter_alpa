import test from 'node:test';
import assert from 'node:assert/strict';
import { createPhotoServer, schema, validOutput, validateImage } from './server.mjs';

function empty(spec = schema) {
  if (spec.type === 'object') return Object.fromEntries(Object.entries(spec.properties)
    .map(([k, v]) => [k, empty(v)]));
  return spec.type === 'array' ? [] : null;
}
const image = { mimeType: 'image/jpeg', image: Buffer.from([255,216,255,224]).toString('base64'), catalogo: [] };

test('output schema rejects missing headers, invalid lists and unexpected properties', () => {
  assert.equal(validOutput(empty()), true);
  assert.equal(validOutput({ ...empty(), cabecera: {} }), false);
  assert.equal(validOutput({ ...empty(), actividades: 'texto' }), false);
  assert.equal(validOutput({ ...empty(), save: true }), false);
  assert.throws(() => validateImage({ ...image, image: 'no-es-una-foto' }));
  assert.throws(() => validateImage({ ...image, mimeType: 'image/png' }));
});

async function fixture(t, { role = 'Master', finishReason = 'STOP', upstreamStatus = 200 } = {}) {
  let geminiCalls = 0;
  const draft = empty();
  const server = createPhotoServer({ apiKey: 'test-key', model: 'test-model',
    profileUrl: 'https://existing-api.example/usuarios/perfil',
    fetchImpl: async (url, options) => {
      if (url.includes('existing-api')) {
        assert.equal(options.headers.Authorization, 'Bearer valid-session');
        return Response.json({ rol: role, codigo_dni: '123' });
      }
      geminiCalls++;
      const body = JSON.parse(options.body);
      assert.equal(options.headers['x-goog-api-key'], 'test-key');
      assert.equal(body.generationConfig.responseMimeType, 'application/json');
      assert.equal(body.contents[0].parts[1].inlineData.data, image.image);
      return Response.json({ candidates: [{ finishReason,
        content: { parts: [{ text: JSON.stringify(draft) }] } }] }, { status: upstreamStatus });
    },
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  return { calls: () => geminiCalls, draft,
    request: (auth = 'Bearer valid-session', body = image) => fetch(
      `http://127.0.0.1:${server.address().port}/tal-largo/preview`, {
        method: 'POST', headers: { Authorization: auth, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }) };
}

test('master gets only an editable draft; repeated requests are limited', async t => {
  const f = await fixture(t);
  const response = await f.request();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), f.draft);
  assert.equal(f.calls(), 1);
  assert.equal((await f.request()).status, 429);
  assert.equal(f.calls(), 1);
});
test('operator cannot send a photo to Gemini', async t => {
  const f = await fixture(t, { role: 'Operador' });
  assert.equal((await f.request()).status, 403);
  assert.equal(f.calls(), 0);
});
test('missing session is rejected before calling the profile API', async t => {
  const f = await fixture(t);
  assert.equal((await f.request('')).status, 401);
  assert.equal(f.calls(), 0);
});
test('incomplete model output never becomes a valid draft', async t => {
  const f = await fixture(t, { finishReason: 'MAX_TOKENS' });
  assert.equal((await f.request()).status, 502);
});
test('free tier quota error is returned without retrying paid models', async t => {
  const f = await fixture(t, { upstreamStatus: 429 });
  assert.equal((await f.request()).status, 429);
  assert.equal(f.calls(), 1);
});
