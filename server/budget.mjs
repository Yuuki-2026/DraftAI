import {mkdirSync,readFileSync,writeFileSync,renameSync,openSync,closeSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
import {ServiceError} from './service.mjs';

// Fail closed: corrupt counters, lock errors or disk failures never grant more calls.
export class ProviderBudget {
 constructor(directory,{max=60,clock=()=>new Date(),initial=0}={}){
  mkdirSync(directory,{recursive:true});this.file=join(directory,'provider-budget.json');this.lock=this.file+'.lock';this.max=max;this.clock=clock;this.initial=initial;
 }
 remaining(){
  try{const data=JSON.parse(readFileSync(this.file,'utf8'));if(!Number.isSafeInteger(data.calls)||data.calls<0)throw new Error('Invalid counter');return data.day===this.clock().toISOString().slice(0,10)?Math.max(0,this.max-data.calls):this.max;}
  catch(e){if(e.code==='ENOENT')return Math.max(0,this.max-this.initial);throw new ServiceError(503,'No se pudo verificar el consumo.','budget_unavailable');}
 }
 reserve(){
  let fd;
  try{fd=openSync(this.lock,'wx');}catch{throw new ServiceError(503,'El control de consumo está ocupado.','budget_unavailable');}
  try{
   const day=this.clock().toISOString().slice(0,10);let data;
   try{data=JSON.parse(readFileSync(this.file,'utf8'));if(typeof data.day!=='string'||!Number.isSafeInteger(data.calls)||data.calls<0)throw new Error('Invalid counter');}
   catch(e){if(e.code!=='ENOENT')throw new ServiceError(503,'No se pudo verificar el consumo.','budget_unavailable');data={day,calls:this.initial};}
   if(data.day!==day)data={day,calls:0};
   if(data.calls>=this.max)throw new ServiceError(429,'El servidor alcanzó su límite global por hoy.','global_limit');
   data.calls++;writeFileSync(this.file+'.tmp',JSON.stringify(data));renameSync(this.file+'.tmp',this.file);return data.calls;
  }finally{closeSync(fd);unlinkSync(this.lock);}
 }
}
