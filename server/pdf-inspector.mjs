import {parentPort,workerData} from 'node:worker_threads';
import {PDFDocument} from 'pdf-lib';
try {
 const pdf=await PDFDocument.load(new Uint8Array(workerData),{ignoreEncryption:false,updateMetadata:false,throwOnInvalidObject:true});
 const pages=pdf.getPageCount();
 parentPort.postMessage({pages,valid:pages>0&&pages<=12});
}catch{parentPort.postMessage({valid:false});}
