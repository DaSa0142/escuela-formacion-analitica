import { jsPDF } from 'jspdf';
const navy=[17,37,65],gold=[183,139,63];
const put=(doc,s,x,y,size=11,color=navy,opt={})=>{doc.setTextColor(...color);doc.setFont('helvetica',opt.bold?'bold':'normal');doc.setFontSize(size);doc.text(String(s),x,y,opt)};
const frame=(doc)=>{doc.setFillColor(...navy);doc.rect(0,0,297,14,'F');doc.rect(0,196,297,14,'F');doc.setDrawColor(...gold);doc.setLineWidth(1.3);doc.rect(10,22,277,165);doc.setLineWidth(.4);doc.rect(14,26,269,157);};
export function certificatePDF({person,certificate,course,courses}){
 const doc=new jsPDF({orientation:'landscape',unit:'mm',format:'a4'});
 frame(doc);
 put(doc,'ESCUELA DE FORMACIÓN ANALÍTICA',148.5,40,12,navy,{align:'center',bold:true});
 put(doc,course?'CERTIFICADO DE APROBACIÓN':'CERTIFICADO GLOBAL DE APROBACIÓN',148.5,60,23,navy,{align:'center',bold:true});
 doc.setDrawColor(...gold);doc.line(94,67,203,67);
 put(doc,'Se certifica que',148.5,80,12,navy,{align:'center'});
 put(doc,(person||'PARTICIPANTE').toUpperCase(),148.5,96,22,navy,{align:'center',bold:true});
 const name=course?.title || 'PROGRAMA INTEGRAL DE FORMACIÓN ANALÍTICA';
 const lines=doc.splitTextToSize(name,235);
 let y=115;
 for(const line of lines){put(doc,line,148.5,y,14,navy,{align:'center',bold:true});y+=8;}
 const total=course?.hours || courses.reduce((a,c)=>a+c.hours,0);
 put(doc,`Ha aprobado satisfactoriamente ${course?'el curso':'los 13 cursos del programa'} con una carga académica de ${total} horas.`,148.5,143,11,navy,{align:'center'});
 put(doc,'Todos los módulos fueron aprobados con una nota mínima de 70/100.',148.5,153,10,navy,{align:'center'});
 put(doc,`Emitido: ${new Date(certificate.issued_at).toLocaleDateString('es-EC')}     Código de verificación: ${certificate.token}`,148.5,174,9,gold,{align:'center'});
 if(!course){
 doc.addPage('a4','landscape');frame(doc);
 put(doc,'ANEXO ACADÉMICO — DETALLE DE CURSOS APROBADOS',148.5,39,16,navy,{align:'center',bold:true});
 put(doc,`Participante: ${person}  |  Cursos aprobados: ${courses.length}`,22,52,10);
 let y2=62;
 doc.setFillColor(...navy);doc.rect(21,y2-5,254,9,'F');
 put(doc,'CÓDIGO',26,y2+1,9,[255,255,255],{bold:true});put(doc,'CURSO',62,y2+1,9,[255,255,255],{bold:true});put(doc,'HORAS',257,y2+1,9,[255,255,255],{bold:true});y2+=10;
 for(const c of courses){
  if(y2>173) {doc.addPage('a4','landscape');frame(doc);y2=43;}
  const ls=doc.splitTextToSize(c.title,190); const rowH=Math.max(7,ls.length*3.5+2);
  if((courses.indexOf(c)%2)===0){doc.setFillColor(244,246,250);doc.rect(21,y2-4,254,rowH,'F');}
  put(doc,c.code,26,y2+1,7);ls.forEach((l,i)=>put(doc,l,62,y2+i*3.5+1,7));put(doc,String(c.hours),263,y2+1,7,navy,{align:'right'});
  y2+=rowH;
 }
 put(doc,`TOTAL: ${total} HORAS ACADÉMICAS`,258,182,11,gold,{align:'right',bold:true});
 put(doc,`Código de certificado: ${certificate.token}`,22,182,8);
 }
 doc.save(`${course?course.code:'EFA-GLOBAL'}-${certificate.token}.pdf`);
}
