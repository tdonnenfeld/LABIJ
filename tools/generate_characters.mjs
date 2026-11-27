import {mkdirSync,writeFileSync} from "node:fs";
function generate(kind) {
 const cfg={rat:["#817061","#b5a18a","#3f312c",0.85],goblin:["#82935d","#776041","#403c28",1.0],brute:["#9d694c","#70533c","#4e3a30",1.25],archer:["#d4cbb2","#a89c7c","#4c4135",0.85],guardian:["#82919a","#536572","#bc9b59",1.10],mage:["#a98eaa","#65506d","#9c7d49",0.9],crypt_warden:["#899ca4","#475766","#bb9c60",1.20],ember_oracle:["#d38c59","#7e4739","#d6a65c",0.95],jewel_sentinel:["#c0a461","#7e754d","#8fbba4",1.25],jewel_hunter:["#a96592","#53445a","#6c8c7e",0.9],adventurer:["#b68a66","#726952","#b1976a",1.0]}[kind];
 const [skin,cloth,metal,wide]=cfg;const bone="#dfd5bb",dark="#312923",steel="#a7b0ab",eye=kind==="ember_oracle"?"#ffb16a":kind==="jewel_sentinel"?"#b9f5be":"#e6cb83";
 const nodes=[],meshes=[],materials=[],views=[],accessors=[],bytes=[],meshCache={};
 const enc=(a)=>{const chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";let s="";for(let i=0;i<a.length;i+=3){const n=(a[i]<<16)|((a[i+1]||0)<<8)|(a[i+2]||0);s+=chars[(n>>18)&63]+chars[(n>>12)&63]+(i+1<a.length?chars[(n>>6)&63]:"=")+(i+2<a.length?chars[n&63]:"=")}return s};
 const acc=(data,type,min,max)=>{const a=new Float32Array(data);const off=bytes.length;bytes.push(...new Uint8Array(a.buffer));const view=views.push({buffer:0,byteOffset:off,byteLength:a.byteLength,target:34962})-1;const obj={bufferView:view,componentType:5126,count:data.length/(type==="VEC3"?3:2),type};if(min)obj.min=min;if(max)obj.max=max;return accessors.push(obj)-1};
 const shapes={};function geometry(shape){if(shapes[shape])return shapes[shape];let pos=[],norm=[],uv=[];function tri(a,b,c){let u=b.map((v,i)=>v-a[i]),v=c.map((x,i)=>x-a[i]);let n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];let l=Math.hypot(...n)||1;n=n.map(x=>x/l);pos.push(...a,...b,...c);norm.push(...n,...n,...n);uv.push(0,0,1,0,.5,1)}
 if(shape==="box"){const a=[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,.5,-.5],[-.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]];for(const [i,j,k,l] of [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]){tri(a[i],a[j],a[k]);tri(a[i],a[k],a[l])}}else{const rings=[[-.5,0],[-.43,.25],[-.25,.44],[.05,.5],[.30,.40],[.45,.23],[.5,0]];for(let j=0;j<rings.length-1;j++){for(let i=0;i<12;i++){const pt=(k,h)=>[Math.cos(k*Math.PI/6)*rings[h][1],rings[h][0],Math.sin(k*Math.PI/6)*rings[h][1]];if(rings[j][1])tri(pt(i,j),pt(i,j+1),pt(i+1,j));if(rings[j+1][1])tri(pt(i+1,j),pt(i,j+1),pt(i+1,j+1))}}}
 return shapes[shape]={POSITION:acc(pos,"VEC3",[-.5,-.5,-.5],[.5,.5,.5]),NORMAL:acc(norm,"VEC3"),TEXCOORD_0:acc(uv,"VEC2")}}
 function mat(color){let i=materials.findIndex(m=>m.name===color);if(i>=0)return i;return materials.push({name:color,pbrMetallicRoughness:{baseColorFactor:[1,3,5].map(i=>parseInt(color.slice(i,i+2),16)/255).concat(1),roughnessFactor:color===metal||color===steel?.48:.88,metallicFactor:color===metal||color===steel?.55:0},doubleSided:true})-1}
 function node(name,at,parent,scale,shape,color){const n={name,translation:at};if(scale)n.scale=scale;if(shape){let key=shape+color;if(meshCache[key]===undefined)meshCache[key]=meshes.push({name:shape+color,primitives:[{attributes:geometry(shape),material:mat(color)}]})-1;n.mesh=meshCache[key]}let i=nodes.push(n)-1;if(parent!==null)(nodes[parent].children??=[]).push(i);return i}
 const root=node("Rig",[0,0,0],null),body=node("Body",[0,0,0],root);let k=0;const part=(p,at,scale,color,shape="box")=>node("Part"+(++k),at,p,scale,shape,color);
 if(kind==="rat"){
  part(body,[0,.36,.05],[.57,.46,.85],skin,"round");part(body,[0,.29,-.42],[.38,.32,.5],skin,"round");part(body,[0,.23,-.68],[.18,.15,.18],dark,"round");
  part(body,[0,.31,-.47],[.30,.13,.26],cloth,"round");
  for(const sign of [-1,1]){part(body,[sign*.09,.19,-.60],[.045,.06,.075],bone,"round");for(let j=0;j<3;j++)part(body,[sign*(.12+j*.025),.23+j*.018,-.59],[.12,.009,.014],cloth)}
  for(const sign of [-1,1]){part(body,[sign*.16,.48,-.40],[.15,.24,.12],cloth,"round");part(body,[sign*.16,.34,-.54],[.045,.045,.05],eye);for(const [name,z] of [["Arm",-.28],["Leg",.30]]){let limb=node(name+(sign<0?"R":"L"),[sign*.21,.23,z],body);part(limb,[0,-.11,0],[.13,.26,.15],skin);part(limb,[0,-.21,-.04],[.15,.08,.22],cloth)}}
  const tail=node("Tail",[0,.30,.43],body);part(tail,[0,-.05,.30],[.065,.07,.64],cloth);part(tail,[0,-.05,.63],[.04,.045,.2],skin);
 }else{
  const armor=["guardian","crypt_warden","jewel_sentinel"].includes(kind),skeleton=kind==="archer",mage=["mage","ember_oracle"].includes(kind);
  part(body,[0,.53,0],[.39*wide,.20,.29],cloth,"round");
  part(body,[0,.72,0],[.46*wide,.32,.28*wide],armor?metal:cloth,"round");
  if(skeleton){for(let j=0;j<4;j++)part(body,[0,.60+j*.07,-.13],[.36-j*.018,.035,.07],bone);part(body,[0,.70,0],[.09,.38,.09],bone)}
  else {part(body,[0,.70,-.12],[.32*wide,.26,.09],armor?skin:cloth);part(body,[0,.55,0],[.46*wide,.07,.32],dark);part(body,[0,.55,-.18],[.11,.09,.04],metal)}
  if(mage){part(body,[0,.43,0],[.48,.36,.34],cloth,"round");part(body,[0,.69,.16],[.50,.53,.09],cloth);part(body,[0,.72,-.16],[.06,.31,.04],metal)}
  const head=node("Head",[0,.91,0],body);
  part(head,[0,.025,0],[.31*wide,.28,.27],armor?skin:(skeleton?bone:skin),"round");
  if(mage||kind==="jewel_hunter"){part(head,[0,.055,.03],[.38,.35,.34],cloth,"round");part(head,[0,-.01,-.14],[.24,.18,.055],dark)}
  if(armor){part(head,[0,.02,-.14],[.29,.17,.06],metal);part(head,[0,.095,0],[.07,.23,.34],metal)}
  for(const sign of [-1,1]){part(head,[sign*.076,.03,-.14],[.052,.035,.035],eye);if(kind==="goblin")part(head,[sign*.20,.025,0],[.18,.10,.09],skin,"round");if(kind==="brute")part(head,[sign*.085,-.08,-.15],[.04,.085,.04],bone)}
  part(head,[0,-.056,-.15],[.12,.04,.025],dark);
  if(!armor&&!mage&&kind!=="jewel_hunter"){part(head,[0,-.005,-.145],[.075,.085,.085],skeleton?bone:skin,"round");part(head,[0,-.09,-.045],[.22*wide,.10,.20],skeleton?bone:skin,"round");for(const sign of [-1,1])part(head,[sign*.08,.065,-.135],[.115,.045,.045],dark,"round")}
  if(skeleton){for(let j=0;j<5;j++)part(head,[(j-2)*.022,-.065,-.169],[.017,.028,.018],bone)}
  if(armor){for(const sign of [-1,1]){part(head,[sign*.125,-.035,-.03],[.06,.17,.20],metal,"round");for(let j=0;j<3;j++)part(head,[sign*.05*j,-.04,-.174],[.014,.065,.012],dark)}}
  if(mage||kind==="jewel_hunter"){for(const sign of [-1,1])part(head,[sign*.14,-.045,-.08],[.055,.19,.15],cloth,"round")}
  for(const sign of [-1,1]){
   const suffix=sign<0?"R":"L";let arm=node("Arm"+suffix,[sign*.25*wide,.81,0],body),leg=node("Leg"+suffix,[sign*.12*wide,.48,0],body);
   part(arm,[0,-.07,0],[.15*wide,.18,.17*wide],armor?skin:(skeleton?bone:skin),"round");
   part(arm,[0,-.23,0],[.12*wide,.23,.13*wide],armor?metal:(skeleton?bone:cloth),"round");
   part(arm,[0,-.36,0],[.13*wide,.13,.13],skin,"round");
   node("Grip"+suffix,[0,-.38,-.03],arm);
   part(leg,[0,-.13,0],[.16*wide,.27,.19],armor?metal:(skeleton?bone:cloth),"round");
   part(leg,[0,-.32,0],[.13*wide,.18,.14],armor?skin:(skeleton?bone:cloth));
   part(leg,[0,-.42,-.055],[.17*wide,.12,.27],dark);
   if(armor){part(arm,[sign*.01,-.025,0],[.24*wide,.15,.22],metal,"round");part(arm,[0,-.235,-.064],[.14*wide,.14,.045],steel,"round");part(leg,[0,-.25,-.075],[.15*wide,.12,.055],metal,"round")}
   else if(!skeleton){part(arm,[0,-.29,0],[.135*wide,.045,.145],dark,"round");part(leg,[0,-.35,0],[.145*wide,.045,.155],dark,"round")}
   if(!skeleton){for(let j=0;j<3;j++)part(arm,[(j-1)*.032*wide,-.397,-.025],[.029*wide,.045,.07],armor?metal:skin,"round");part(leg,[0,-.43,-.10],[.16*wide,.075,.17],armor?metal:cloth,"round")}
  }
  if(!skeleton){for(const sign of [-1,1]){part(body,[sign*.145*wide,.73,-.15],[.06,.29,.035],armor?metal:dark);part(body,[sign*.18*wide,.55,-.16],[.055,.055,.035],metal,"round")}if(armor){for(let j=0;j<3;j++)part(body,[0,.61+j*.06,-.165],[.30*wide,.035,.035],skin,"round")}else if(mage){for(const sign of [-1,1])part(body,[sign*.16,.48,-.14],[.075,.30,.04],metal)}}
  if(kind==="crypt_warden"||kind==="jewel_sentinel"){part(head,[0,.19,0],[.40,.07,.34],metal);for(let j=-1;j<=1;j++)part(head,[j*.13,.24,0],[.06,.15,.07],metal);part(body,[0,.75,-.19],[.13,.15,.07],eye,"round")}
  if(kind==="ember_oracle")part(head,[0,.17,0],[.13,.19,.14],eye,"round");
 }
 const model={asset:{version:"2.0",generator:"LABIJ original low-poly workshop"},scene:0,scenes:[{name:kind,nodes:[root]}],nodes,meshes,materials,buffers:[{byteLength:bytes.length,uri:"data:application/octet-stream;base64,"+enc(bytes)}],bufferViews:views,accessors};
 return JSON.stringify(model);
}
const kinds=["rat","goblin","brute","archer","guardian","mage","crypt_warden","ember_oracle","jewel_sentinel","jewel_hunter","adventurer"];
mkdirSync("art/models/characters",{recursive:true});
for(const kind of kinds) writeFileSync("art/models/characters/"+kind+".gltf",generate(kind)+"\n");
