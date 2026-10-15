import test from 'node:test';
import assert from 'node:assert/strict';
import {DailyQuota, validateTransform, validateFiles, executeAi} from './service.mjs';
test('quota is per authenticated user, resets daily and refunds only once', () => {
  let now = new Date('2026-10-15T12:00:00Z'); const q = new DailyQuota(() => now);
  q.reserve('a', false); const refund = q.reserve('a', false);
  assert.throws(() => q.reserve('a', false)); refund(); refund(); q.reserve('a', false);
  assert.throws(() => q.reserve('a', false)); now = new Date('2026-10-16T00:00:00Z'); q.reserve('a', false);
});
test('empty text and invalid OCR files are rejected before provider call', () => {
  assert.throws(() => validateTransform({text: '', action: 'summarize'}));
  assert.throws(() => validateFiles({files: [{mime: 'application/pdf', base64: 'AA=='}]}));
});
test('gateway maps provider response without exposing credentials', async () => {
  const config = {key: 'only-a-test-key', model: 'test-model', url: 'https://example.test/chat'};
  const result = await executeAi('/v1/transform', {text: 'Material', action: 'summarize'}, config,
    async (_url, request) => {
      assert.equal(JSON.parse(request.body).model, 'test-model');
      return new Response(JSON.stringify({choices: [{message: {content: 'Resumen'}}]}));
    });
  assert.deepEqual(result, {text: 'Resumen'});
});
