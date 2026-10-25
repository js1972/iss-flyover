// Full-Moon observing opportunities, independent of network and device time zone.
// Exact phase time is metadata; start/end describe the locally usable night.
var LunarEvents = (() => {
  const date = t => new Date(t * 1000);
  const seconds = time => time ? +time.date / 1000 : null;
  function forNight({day, night, now, location, eveningFirst, position, sunAltitude}) {
    const phase = Astronomy.SearchMoonPhase(180, date(night.start - 2 * 86400), 5);
    if (!phase) return [];
    const fullMoonAt = seconds(phase);
    const todaySunrise = SunCalc.getTimes(date(day.noon), location.latitude, location.longitude).sunrise;
    const primaryStart = Number.isFinite(+todaySunrise) ? +todaySunrise / 1000 : day.dayStart;
    const primaryEnd = night.sunrise ?? day.nextDayStart;
    const isPrimary = fullMoonAt >= primaryStart && fullMoonAt < primaryEnd;
    // Adjacent evenings are explicitly 'nearly full', never a second exact phase.
    if (!isPrimary && Math.abs(fullMoonAt - (night.start + 7200)) > 36 * 3600) return [];

    const observer = new Astronomy.Observer(location.latitude, location.longitude, 0);
    const moonrise = seconds(Astronomy.SearchRiseSet('Moon', observer, 1, date(day.dayStart), (night.end-day.dayStart)/86400));
    const moonset = seconds(Astronomy.SearchRiseSet('Moon', observer, -1, date(night.start), (night.end-night.start)/86400));
    const point = timestamp => ({timestamp, ...position('Moon', timestamp, location)});
    const usable = t => point(t).elevation >= 5 && sunAltitude(t, location) <= -0.833;
    // Five-minute samples also let cached widget timelines advance their preview
    // time without running JavaScriptCore on every timeline entry.
    const events = [];
    let samples = [], start = null;
    function boundary(a, b, entering) {
      for (let i=0; i<12; i++) {
        const mid = (a+b)/2;
        if (usable(mid) === entering) b=mid; else a=mid;
      }
      return entering ? b : a;
    }
    function flush(end) {
      if (start == null) return;
      if (end > now && end-start >= 60) {
        if (samples[samples.length-1]?.timestamp !== end) samples.push(point(end));
        const remaining = samples.filter(p => p.timestamp >= now && p.timestamp < end);
        // Prefer an early, comfortably elevated view over waiting until transit.
        const evening = eveningFirst ? remaining.filter(p => p.timestamp < day.midnight) : [];
        const preferred = evening.length ? evening : remaining;
        const focus = preferred.find(p => p.elevation >= 10) ?? preferred[0];
        if (focus) events.push({
          id:`moon-${Math.round(fullMoonAt)}-${day.id}-${Math.round(start)}`, kind:'moon',
          title:isPrimary ? 'Full Moon' : 'Nearly full Moon', body:'Moon',
          nightID:day.id, start, end, focus:focus.timestamp,
          azimuth:focus.azimuth, elevation:focus.elevation, isMorning:focus.timestamp >= day.midnight,
          score:isPrimary ? 180 : 110, points:[],
          detail:isPrimary ? 'Watch the full Moon above the horizon. Bright moonlight washes out faint stars.' : 'The Moon looks nearly full tonight. Bright moonlight washes out faint stars.',
          lunar:{fullMoonAt, moonrise, moonset, isPrimary, midnight:day.midnight, samples}
        });
      }
      samples=[]; start=null;
    }
    let previous = night.start, wasUsable = usable(previous);
    if (wasUsable) { start=previous; samples.push(point(previous)); }
    for (let t=Math.min(previous+300,night.end); t<=night.end; t=Math.min(t+300,night.end)) {
      const visible=usable(t);
      if (visible && !wasUsable) { start=boundary(previous,t,true); samples.push(point(start)); }
      if (visible && t !== start) samples.push(point(t));
      if (!visible && wasUsable) flush(boundary(previous,t,false));
      previous=t; wasUsable=visible;
      if (t===night.end) break;
    }
    if (start != null) flush(night.end);
    return events;
  }
  return {forNight};
})();
