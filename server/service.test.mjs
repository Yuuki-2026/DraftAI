import test from 'node:test';
import assert from 'node:assert/strict';
import {DailyQuota,validateTransform,validateFiles,executeAi} from './service.mjs';
test('quota per user, daily reset, single refund',()=>{
 let now=new Date('2026-10-15T12:00:00Z');const q=new DailyQuota(()=>now);q.reserve('a',false);const refund=q.reserve('a',false);
 assert.throws(()=>q.reserve('a',false));refund();refund();q.reserve('a',false);assert.throws(()=>q.reserve('a',false));now=new Date('2026-10-16');q.reserve('a',false);
});
test('scope, input size and disguised files rejected before provider',()=>{
 assert.throws(()=>validateTransform({text:'a',action:'chat'}));assert.throws(()=>validateTransform({text:'a',action:'improve',messages:[]}));
 assert.throws(()=>validateTransform({text:'a'.repeat(12001),action:'summarize'}));
 assert.throws(()=>validateFiles({files:[{mime:'image/png',base64:Buffer.from('MZ executable').toString('base64')}],folders:[],categories:[]}));
});
const config={key:'test-only',model:'fixed-model',url:'https://example.test/chat'};
test('guard denial prevents generation',async()=>{
 let calls=0;await assert.rejects(()=>executeAi('/v1/transform',{text:'unsafe material',action:'improve'},config,async()=>{calls++;return Response.json({choices:[{message:{content:'{"allowed":false}'}}]});}),e=>e.code==='content_blocked');assert.equal(calls,1);
});
test('fixed model, bounded output, input and output moderation',async()=>{
 let calls=0;const out=await executeAi('/v1/transform',{text:'Material',action:'summarize'},config,async(_,request)=>{
  const b=JSON.parse(request.body);assert.equal(b.model,'fixed-model');assert.ok(b.max_completion_tokens<=1536);assert.equal(b.tools,undefined);
  calls++;return Response.json({choices:[{message:{content:calls===2?'{"refused":false,"text":"# Resumen\\nContenido"}':'{"allowed":true}'}}]});
 });assert.equal(calls,3);assert.equal(out.model,'fixed-model');assert.ok(out.text.startsWith('#'));
});
test('unsafe provider output never reaches caller',async()=>{
 let calls=0;await assert.rejects(()=>executeAi('/v1/transform',{text:'Material',action:'improve'},config,async()=>{
  calls++;return Response.json({choices:[{message:{content:calls===2?'{"refused":false,"text":"unsafe"}':calls===3?'{"allowed":false}':'{"allowed":true}'}}]});
 }),e=>e.code==='content_blocked');
});
