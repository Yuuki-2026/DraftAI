import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,writeFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {ProviderBudget} from './budget.mjs';
test('global budget survives a process restart and cannot reset on malformed state',()=>{
 const dir=mkdtempSync(join(tmpdir(),'draftai-budget-'));
 try{new ProviderBudget(dir,{max:2}).reserve();new ProviderBudget(dir,{max:2}).reserve();
 assert.throws(()=>new ProviderBudget(dir,{max:2}).reserve(),e=>e.code==='global_limit');
 writeFileSync(join(dir,'provider-budget.json'),'corrupt');assert.throws(()=>new ProviderBudget(dir).reserve(),e=>e.code==='budget_unavailable');
 }finally{rmSync(dir,{recursive:true,force:true});}
});
