import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { qualifyPass } from '../assets/js/pass-visibility.js';
const sample = (timestamp, elevation = 30, sunlit = true) => ({ timestamp, elevation, sunlit, azimuth: 90 });
const pass = points => ({ points, peakPoint: points.reduce((a,b) => a.elevation > b.elevation ? a : b), start: points[0].timestamp, end: points.at(-1).timestamp });

test('Earth shadow and unknown illumination never produce a visible pass', () => {
  for (const sunlight of [false, undefined]) {
    const result = qualifyPass(pass(Array.from({length:19},(_,i)=>({...sample(i*10,70),sunlit:sunlight}))),()=>-40);
    assert.equal(result[0].visible,false);
  }
});
test('clips a pass at shadow entry; peak and duration describe the visible portion', () => {
  const points=Array.from({length:19},(_,i)=>sample(i*10,i<10?25:70,i<10));
  const [result]=qualifyPass(pass(points),()=>-12);
  assert.equal(result.visible,true); assert.equal(result.end,90); assert.equal(result.maxEl,25);
  assert.equal(result.points.length,10); assert.ok(result.points.every(p=>p.sunlit));
});
test('does not join short segments across shadow, twilight, or missing samples', () => {
  const points=Array.from({length:13},(_,i)=>sample(i*10,30,i!==6));
  assert.equal(qualifyPass(pass(points),()=>-10)[0].visible,false);
  assert.equal(qualifyPass(pass(points.map(p=>({...p,sunlit:true}))),t=>t===60?-2:-10)[0].visible,false);
  assert.equal(qualifyPass(pass([sample(0),sample(10),sample(120),sample(130)]),()=>-10)[0].visible,false);
});
test('enforces altitude, twilight and exact one-minute boundary', () => {
  const points=Array.from({length:7},(_,i)=>sample(i*10,20));
  assert.equal(qualifyPass(pass(points),()=>-10)[0].visible,true);
  assert.equal(qualifyPass(pass(points),()=>0)[0].visible,false);
  assert.equal(qualifyPass(pass(points.map(p=>({...p,elevation:19.9}))),()=>-10)[0].visible,false);
});
test('real Perth October orbit: PWA midnight picks are eclipsed; native agrees', () => {
  const ctx=vm.createContext({});vm.runInContext(fs.readFileSync('ios/Resources/SkyEngine.js','utf8'),ctx);
  const orbit=JSON.parse(fs.readFileSync(new URL('fixtures/iss-2026-10-13.json',import.meta.url)));
  const s=ctx.satellite, rec=s.json2satrec(JSON.parse(orbit.omm)), deg=180/Math.PI;
  const location={latitude:-31.9523,longitude:115.8613};
  const now=Date.parse('2026-10-14T08:00:00Z')/1000;
  const days=Array.from({length:7},(_,i)=>{const noon=Date.parse('2026-10-14T04:00:00Z')/1000+i*86400;const id=new Date(noon*1000).toISOString().slice(0,10);return {id,monthDay:id.slice(5),noon,nextNoon:noon+86400,midnight:noon+43200};});
  const forecast=JSON.parse(ctx.SkyEngine.forecast(JSON.stringify({location,now,days,orbit,eveningFirst:true})));
  assert.equal(forecast.events.filter(e=>e.kind==='iss').length,0);
  const points=[];
  for(let t=Date.parse('2026-10-14T17:08:00Z')/1000;t<=Date.parse('2026-10-14T17:18:00Z')/1000;t+=10){
    const d=vm.runInContext(`new Date(${t*1000})`,ctx),p=s.propagate(rec,d).position;
    const elevation=s.ecfToLookAngles({latitude:location.latitude/deg,longitude:location.longitude/deg,height:0},s.eciToEcf(p,s.gstime(d))).elevation*deg;
    if(elevation<=0)continue;
    const sun=s.sunPos(s.jday(d)).rsun;
    const shadow=s.shadowFraction(sun,p);
    // Independent cylindrical shadow check using Astronomy Engine's Sun vector.
    const a=ctx.Astronomy.GeoVector('Sun',d,true),length=Math.hypot(a.x,a.y,a.z);
    const along=(p.x*a.x+p.y*a.y+p.z*a.z)/length;
    assert.ok(along<0 && Math.sqrt(p.x*p.x+p.y*p.y+p.z*p.z-along*along)<6378);
    assert.equal(shadow,1);
    points.push(sample(t,elevation,shadow<0.1));
  }
  const geometric=pass(points);
  assert.ok(geometric.peakPoint.elevation>70); assert.ok(geometric.end-geometric.start>120);
  assert.equal(qualifyPass(geometric,()=>-46)[0].visible,false);
});
