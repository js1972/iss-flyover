// Pure calculation boundary: seconds since Unix epoch in/out, no DOM, network or device timezone.
var SkyEngine = (() => {
  const deg = 180 / Math.PI;
  const seconds = d => d instanceof Date && Number.isFinite(+d) ? +d / 1000 : null;
  const date = t => new Date(t * 1000);
  const direction = az => ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW'][Math.round(az / 22.5) % 16];
  function position(body, t, loc, ra, dec) {
    const observer = new Astronomy.Observer(loc.latitude, loc.longitude, 0);
    const eq = ra == null ? Astronomy.Equator(body, date(t), observer, true, true) : {ra, dec};
    const h = Astronomy.Horizon(date(t), observer, eq.ra, eq.dec, 'normal');
    return {azimuth:h.azimuth, elevation:h.altitude};
  }
  function sunAltitude(t, loc) { return SunCalc.getPosition(date(t), loc.latitude, loc.longitude).altitude * deg; }
  function recordOrbit(orbit) {
    if (!orbit) return null;
    if (orbit.omm) return satellite.json2satrec(JSON.parse(orbit.omm));
    if (orbit.line1 && orbit.line2) return satellite.twoline2satrec(orbit.line1, orbit.line2);
    return null;
  }
  function issPoint(satrec, t, loc) {
    const pv = satellite.propagate(satrec, date(t));
    if (!pv || !pv.position || satrec.error) return null;
    const gmst = satellite.gstime(date(t));
    const look = satellite.ecfToLookAngles({latitude:loc.latitude/deg, longitude:loc.longitude/deg, height:0}, satellite.eciToEcf(pv.position, gmst));
    const shadow = satellite.shadowFraction(satellite.sunPos(satellite.jday(date(t))).rsun, pv.position);
    return {timestamp:t, azimuth:look.azimuth*deg, elevation:look.elevation*deg, sunlit:shadow < 0.1};
  }
  function passes(satrec, loc, start, end) {
    if (!satrec) return [];
    const output = [];
    let above = false, rise = start;
    function refine(a,b) {
      let segment = [];
      const flush = () => {
        if (segment.length < 2) { segment=[]; return; }
        const peak = segment.reduce((a,b)=>a.elevation>b.elevation?a:b);
        const first=segment[0], last=segment[segment.length-1];
        if (peak.elevation >= 20 && last.timestamp-first.timestamp >= 60) {
          output.push({id:`iss-${Math.round(first.timestamp)}`, kind:'iss', title:'ISS flyover', start:first.timestamp, end:last.timestamp,
            focus:peak.timestamp, azimuth:first.azimuth, elevation:peak.elevation, score:100+peak.elevation,
            detail:`Look ${direction(first.azimuth)} → ${direction(last.azimuth)} · ${Math.round(peak.elevation)}° high · ${Math.round((last.timestamp-first.timestamp)/60)} min`,
            body:'ISS', points:segment, nightID:'', isMorning:false});
        }
        segment=[];
      };
      for(let t=a;t<=b;t+=10) {
        const p=issPoint(satrec,t,loc);
        // Visibility is the illuminated portion of a pass while the observer is in darkness.
        if(p && p.elevation>0 && p.sunlit && sunAltitude(t,loc)<-6) segment.push(p); else flush();
      }
      flush();
    }
    for(let t=start;t<=end;t+=60) {
      const p=issPoint(satrec,t,loc);
      if(p && p.elevation>0) { if(!above) rise=Math.max(start,t-60); above=true; }
      else if(above) { refine(rise,t); above=false; }
    }
    if(above) refine(rise,end);
    return output;
  }
  function forecast(input) {
    const loc=input.location, events=[], nights=[];
    for(const day of input.days) {
      const st=SunCalc.getTimes(date(day.noon),loc.latitude,loc.longitude);
      const nt=SunCalc.getTimes(date(day.nextNoon),loc.latitude,loc.longitude);
      const sunset=seconds(st.sunset), sunrise=seconds(nt.sunrise);
      const start=sunset || day.noon, end=sunrise || day.nextNoon;
      if(end<=input.now) continue;
      const moon=SunCalc.getMoonIllumination(date(start+7200));
      const night={id:day.id, start,end,sunset,sunrise,dark:seconds(st.night), dawn:seconds(nt.nightEnd),moonPercent:Math.round(moon.fraction*100),moonPhase:moon.phase,polar:!sunset || !sunrise};
      nights.push(night);
      const targets=[...['Mercury','Venus','Mars','Jupiter','Saturn'].map(body=>({id:body,name:body,body,kind:'planet',score:90})),
        ...DEEP_SKY_TARGETS.map(x=>({...x,body:x.name,kind:'deepSky',score:60})),
        ...BRIGHT_STARS.filter(x=>x.mag<0.5).map(x=>({...x,body:x.name,kind:'star',score:45}))];
      for(const shower of METEOR_SHOWERS) {
        const md=day.monthDay;
        const active=shower.activeStart>shower.activeEnd ? md>=shower.activeStart || md<=shower.activeEnd : md>=shower.activeStart && md<=shower.activeEnd;
        if(active) targets.push({...shower,body:shower.name,kind:'meteor',raHours:shower.radiantRaHours,decDeg:shower.radiantDecDeg,score:day.monthDay===shower.peakMonthDay?125:65});
      }
      for(const target of targets) {
        let best=null;
        for(let t=Math.max(start,input.now);t<end;t+=1200) {
          const sun=sunAltitude(t,loc);
          const maxSun=target.body==='Venus'?-2:target.kind==='planet'?-6:-12;
          if(sun>maxSun) continue;
          const p=position(target.body,t,loc,target.raHours,target.decDeg);
          if(p.elevation < (target.kind==='planet'?8:20)) continue;
          const morning=t>=day.midnight;
          const m=SunCalc.getMoonPosition(date(t),loc.latitude,loc.longitude);
          const moonPenalty=m.altitude>0 && target.kind!=='planet' && target.kind!=='star' ? moon.fraction*30:0;
          const score=target.score+p.elevation*0.45-moonPenalty+(input.eveningFirst && !morning?45:0);
          if(!best || score>best.score) best={...p,focus:t,score,isMorning:morning};
        }
        if(best) events.push({id:`${target.id}-${day.id}`,kind:target.kind,title:target.name,body:target.body,nightID:day.id,
          start:Math.max(start,best.focus-1200),end:Math.min(end,best.focus+1200),...best,
          ra:target.raHours ?? null,dec:target.decDeg ?? null,points:[],
          detail:target.kind==='meteor'?'Active shower · look across a dark sky; rates vary':target.hint || `Look ${direction(best.azimuth)} · ${Math.round(best.elevation)}° above the horizon`});
      }
    }
    const satrec=recordOrbit(input.orbit);
    const iss=passes(satrec,loc,input.now,Math.min(nights[nights.length-1]?.end || input.now, input.orbit ? input.orbit.epoch+7*86400 : input.now));
    for(const event of iss) {
      const night=nights.find(n=>event.focus>=n.start && event.focus<=n.end);
      if(night) { event.nightID=night.id; event.isMorning=event.focus>=input.days.find(d=>d.id===night.id).midnight; events.push(event); }
    }
    return {nights:nights.slice(0,7),events:events.filter(e=>nights.slice(0,7).some(n=>n.id===e.nightID)).sort((a,b)=>a.focus-b.focus)};
  }
  function chart(input) {
    const loc=input.location, t=input.time;
    const objects=[...['Mercury','Venus','Mars','Jupiter','Saturn','Moon'].map(body=>({id:body,name:body,body,kind:body==='Moon'?'moon':'planet'})),
      ...BRIGHT_STARS.map(x=>({...x,body:x.name,kind:'star'})), ...DEEP_SKY_TARGETS.map(x=>({...x,body:x.name,kind:'deepSky'}))];
    if(input.target?.kind==='meteor' && input.target.ra != null && input.target.dec != null) {
      objects.push({id:input.target.id,name:input.target.title,body:input.target.body,kind:'meteor',raHours:input.target.ra,decDeg:input.target.dec});
    }
    const points=objects.map(o=>({id:o.id,name:o.name,kind:o.kind,...position(o.body,t,loc,o.raHours,o.decDeg)})).filter(o=>o.elevation>0);
    const rec=recordOrbit(input.orbit);
    if(rec) { const p=issPoint(rec,t,loc); if(p && p.elevation>0) points.push({id:'ISS',name:p.sunlit?'ISS':'ISS (in shadow)',kind:'iss',...p}); }
    return points;
  }
  return {forecast:input=>JSON.stringify(forecast(JSON.parse(input))),chart:input=>JSON.stringify(chart(JSON.parse(input)))};
})();
