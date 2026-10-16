import {readFileSync,writeFileSync,renameSync} from 'node:fs';
import {join} from 'node:path';import {homedir} from 'node:os';
const file=join(homedir(),'.codex','.secrets','draftai','runtime','usage.json');
const state=JSON.parse(readFileSync(file,'utf8'));
const active=state.devices.filter(d=>d.expires>Date.now());
const [action='list',selector='latest']=process.argv.slice(2);
if(action==='list'){for(const d of active)console.log(`${d.hash.slice(0,12)} ${d.pro?'Pro test':'Free'} expires ${new Date(d.expires).toISOString()}`);}
else{
 if(!['pro','free'].includes(action))throw new Error('Use: list | pro latest | free <device-prefix>');
 const device=selector==='latest'?active.at(-1):active.find(d=>d.hash.startsWith(selector));
 if(!device)throw new Error('No active test device');device.pro=action==='pro';
 writeFileSync(file+'.tmp',JSON.stringify(state));renameSync(file+'.tmp',file);
 console.log(`${device.hash.slice(0,12)}: ${action}. Global provider budget remains capped.`);
}
